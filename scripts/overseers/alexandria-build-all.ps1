param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$Title = "",
  [string]$Prompt = "",
  [object]$Events = 7,
  [object]$NPCs = 12,
  [object]$Regions = 5
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

function Iso { (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return "avalon" } ($s.ToLower() -replace '[^a-z0-9]+','-').Trim('-') }

[int]$EventsI  = As-Int $Events 7
[int]$NPCsI    = As-Int $NPCs 12
[int]$RegionsI = As-Int $Regions 5

$root = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }

$wid = (Iso) + "-" + (Slug $Title)
$worldDir = Join-Path $root $wid
New-Item -ItemType Directory -Force -Path $worldDir | Out-Null

# Seed
$seed = [ordered]@{
  id=$wid; title=$Title; prompt=$Prompt; created=(Get-Date).ToUniversalTime().ToString('o');
  regions=$RegionsI; npc_target=$NPCsI; timeline_events=$EventsI;
  tags=@("isekai","dnd","avalon")
}
$seedPath = Join-Path $worldDir ("seed-"+$wid+".json")
$seed | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $seedPath -Encoding UTF8

# Timeline
$events = @()
for($i=1;$i -le [Math]::Max(1,$EventsI);$i++){
  $events += @{ idx=$i; title="Event $i"; era= ("Age " + [math]::Ceiling($i/3.0)); summary="Placeholder world event $i." }
}
$timeline = @{ world=$wid; events=$events }
$timeline | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "timeline.json") -Encoding UTF8

# NPC codex
$npc=@()
for($n=1;$n -le [Math]::Max(1,$NPCsI);$n++){
  $npc += @{ id=("npc-"+$n); name=("NPC "+$n); role="support"; origin="kingdom"; notes="Placeholder" }
}
$npc | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "npc-codex.json") -Encoding UTF8

# Atlas
$regionsAry=@()
for($r=1;$r -le [Math]::Max(1,$RegionsI);$r++){
  $regionsAry += @{ id=("region-"+$r); name=("Region "+$r); biomes=@("plains"); settlements=@("Town A","Village B") }
}
$atlas = @{ world=$wid; regions=$regionsAry }
$atlas | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "atlas.json") -Encoding UTF8

# Lore bible (skeleton)
$bible = [ordered]@{
  world=$wid;
  themes=@("hope","sacrifice");
  magic_system=@{ source="mana"; rules=@("conservation","cost"); };
  pantheon=@("trickster","war","nature","sea");
  factions=@(@{ id="crown"; ethos="order" }, @{ id="veil"; ethos="secrets" });
}
$bible | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "lore-bible.json") -Encoding UTF8

# Mark latest
"$wid" | Set-Content -LiteralPath (Join-Path $root "latest.txt") -Encoding UTF8
Write-Host "World created: $wid"
