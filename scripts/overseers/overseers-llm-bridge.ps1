param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [string]$Model = "gpt-4o-mini",
  [object]$Temperature = "0.7",
  [object]$MaxTokens = "1500",
  [switch]$ForceOffline
)
$ErrorActionPreference='Stop'

function As-Int([object]$x, [int]$default){
  if ($null -eq $x) { return $default }
  if ($x -is [int]) { return [int]$x }
  if ($x -is [long]) { return [int]$x }
  if ($x -is [double]) { return [int][Math]::Round($x) }
  if ($x -is [string]) { $s=$x.Trim(); if ($s -eq "") { return $default }; return [int]$s }
  if ($x -is [object[]]) {
    foreach($e in $x){ if($null -ne $e -and "$e".Trim() -ne ""){ return [int]("$e") } }
    return $default
  }
  return [int]("$x")
}

[int]$MaxTok = As-Int $MaxTokens 1500
# Temperature can be float; we leave as string to pass through JSON.

$worldsRoot = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if([string]::IsNullOrWhiteSpace($World)){
  $latest = Join-Path $worldsRoot "latest.txt"
  if(!(Test-Path $latest)){ throw "No worlds yet. Run avalon-run-all first." }
  $World = Get-Content -LiteralPath $latest -TotalCount 1
}
$dir = Join-Path $worldsRoot $World
if(!(Test-Path $dir)){ throw "World not found: $World" }

# Read world context safely
function Read-Json([string]$p){ if(Test-Path $p){ try { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } catch { $null } } else { $null } }
$seed = Read-Json (Join-Path $dir "seed-$World.json")
$atlas = Read-Json (Join-Path $dir "atlas.json")
$bible = Read-Json (Join-Path $dir "lore-bible.json")
$timeline = Read-Json (Join-Path $dir "timeline.json")
$npc = Read-Json (Join-Path $dir "npc-codex.json")

# Fallback builder
function Build-Fallback {
  $out = [ordered]@{
    world=$World; generated=(Get-Date).ToUniversalTime().ToString('o');
    quests=@(
      @{ id="q1"; title="The Shattered Wing"; beats=@("hook","rising","climax"); reward="favor of the crown" },
      @{ id="q2"; title="Echoes in the Leylines"; beats=@("mystery","reveal","decision"); reward="rare spell" }
    );
    dialog_samples=@(@{ npc="innkeeper"; lines=@("Welcome, traveler.","The stew is hot, the rumors hotter.") })
  }
  return $out
}

$enriched = $null
if($ForceOffline -or [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)){
  $enriched = Build-Fallback
}else{
  try{
    $sys = @"
You are Alexandria, master worldbuilding DM/Author. You expand structured JSON for a coherent, PG-13 fantasy setting. Return compact JSON only.
"@
    $usr = @{
      instruction = "Expand with quest hooks, regional conflicts, notable NPC motivations, and 10 plot seeds.";
      seed = $seed; atlas=$atlas; bible=$bible; timeline=$timeline; npc=$npc
    } | ConvertTo-Json -Depth 100

    $body = @{
      model = $Model
      messages = @(
        @{ role="system"; content=$sys },
        @{ role="user"; content=$usr }
      )
      max_tokens = $MaxTok
      temperature = [double]::Parse("$Temperature")
    } | ConvertTo-Json -Depth 100

    $resp = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method Post -Headers @{ Authorization = "Bearer $($env:OPENAI_API_KEY)"; "Content-Type"="application/json" } -Body $body
    $content = $resp.choices[0].message.content
    try { $enriched = $content | ConvertFrom-Json } catch { $enriched = @{ text=$content } }
  }catch{
    Write-Warning "LLM call failed: $($_.Exception.Message). Using fallback."
    $enriched = Build-Fallback
  }
}

$path = Join-Path $dir "enriched.json"
$enriched | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
