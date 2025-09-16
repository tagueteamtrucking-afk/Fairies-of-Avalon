[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$SeedPath="",
  [int]$Count=7,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){return "world"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$root = (Resolve-Path $RepoRoot).Path
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { throw "No seeds directory found: $worldsDir" }

# Resolve seed file
$seedFile = $null
if ($SeedPath) {
  $candidate = Join-Path $RepoRoot $SeedPath
  if (-not (Test-Path $candidate)) { throw "Seed file not found: $SeedPath" }
  $seedFile = Get-Item $candidate
} else {
  $files = Get-ChildItem $worldsDir -Filter *.json | Sort-Object LastWriteTime -Descending
  if ($files.Count -eq 0) { throw "No seed files found under /pages/apps/alexandria/worlds. Generate one first." }
  $seedFile = $files | Select-Object -First 1
}

# Load seed
try{ $seed = Get-Content -Raw -Path $seedFile.FullName | ConvertFrom-Json -Depth 100 }catch{ throw "Invalid seed JSON: $($seedFile.FullName)" }

function New-Event([string]$act,[string]$name,[string]$summary,[string]$tag){
  return [pscustomobject]@{ id=[guid]::NewGuid().ToString().Substring(0,8); act=$act; name=$name; summary=$summary; tag=$tag }
}

$f1 = if($seed.factions.Count -ge 1){ $seed.factions[0].name } else { 'Faction A' }
$f2 = if($seed.factions.Count -ge 2){ $seed.factions[1].name } else { 'Faction B' }
$magic = $seed.pillars.magic_system
$travel= $seed.pillars.travel
$topo  = $seed.cosmology.planar_topology

$base = @(
  (New-Event 'I'  'Arrival / Omen'             'A sign or translation event sets the tone.' 'hook'),
  (New-Event 'I'  "First Contact ($f1)"        'Guide or gatekeeper outlines constraints.'   'contact'),
  (New-Event 'II' 'Crossing a Threshold'       "Using $travel exposes costs of $magic."       'threshold'),
  (New-Event 'II' "Rival Move ($f2)"           'Escalation forces a risky bargain.'          'rival'),
  (New-Event 'II' "Revelation of $topo"        'Map or myth clarifies the true stakes.'      'revelation'),
  (New-Event 'III' 'Clash of Factions'         'Allies and debts are tested.'                'climax'),
  (New-Event 'III' 'Choice & Consequence'      'Values win or cost everything.'              'resolution')
)

$events = $base[0..([Math]::Min($Count-1, $base.Count-1))]

# Optional LLM expansion (non-fatal)
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $prompt = @"
Improve each event summary to 1-2 vivid sentences tailored to this seed (keep same order).
Return ONLY a JSON array of strings of equal length to the input.
Seed:
$($seed | ConvertTo-Json -Depth 30)
Events (names only):
$([string]::Join("`n", ($events | ForEach-Object { $_.name })))
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.timeline.expanded.json"
  try{
    & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false
    $arr = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 50
    if ($arr -and $arr.Count -eq $events.Count){
      for($i=0;$i -lt $events.Count;$i++){ $events[$i].summary = [string]$arr[$i] }
    }
  }catch{}
}

$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/timelines"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.timeline.json"
$rel  = "/apps/alexandria/worlds/timelines/$name"
$timeline = [pscustomobject]@{
  id = "timeline-" + (Get-Date -Format 'yyyyMMddHHmmss')
  seed_id = $seed.id
  title = $seed.title
  events = $events
  generated = Iso
  format_version = "1.0.0"
}
($timeline | ConvertTo-Json -Depth 200) | Set-Content -Path (Join-Path $outDir $name) -Encoding utf8NoBOM

# Index update
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 50 } catch { $index=@() } }
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$timeline.id; events=$events.Count; ts=(Iso) }
($index | ConvertTo-Json -Depth 50) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "Timeline written: $rel"
exit 0
