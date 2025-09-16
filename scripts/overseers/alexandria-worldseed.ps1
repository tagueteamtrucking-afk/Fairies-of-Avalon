[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Title="",
  [string]$Prompt="",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'

# Helpers
function Slug([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "world" }
  $t = ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower()
  if ($t.Length -gt 80) { $t = $t.Substring(0,80) }
  return $t
}

# Paths
$root = (Resolve-Path $RepoRoot).Path
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

# Defaults (deterministic but varied)
$magicSystems = @('ritual-magic','runic-tech','spirit-currency','celestial-contracts','bioluminal-weaving')
$techLevels   = @('medieval','clockwork','industrial','diesel','digital','fusion','mythic')
$travels      = @('portals','skyships','dream-walking','river-gates','starlight-bridges')
$topologies   = @('nested-rings','world-tree','shattered-archipelago','spiral-tower','clockwork-spheres')
$factions2 = @(
  @{ name='Order of Lanterns'; motif='guidance'; goal='contain the night' },
  @{ name='Mirror Syndicate'; motif='reflection'; goal='exploit thresholds' },
  @{ name='Skyrail Guild'; motif='motion'; goal='map the winds' },
  @{ name='Umbral Courts'; motif='oaths'; goal='bind errant powers' }
)

# Seed base from prompt where possible
function TitleFromPrompt([string]$p){
  if ([string]::IsNullOrWhiteSpace($p)) { return $null }
  $p = ($p -replace '\s+',' ').Trim()
  $words = $p.Split(' ')
  $take = [Math]::Min(6, $words.Length)
  $t = [string]::Join(' ', $words[0..($take-1)])
  return ($t.Substring(0,1).ToUpper()+$t.Substring(1))
}

$ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$title = if(-not [string]::IsNullOrWhiteSpace($Title)) { $Title } else { TitleFromPrompt $Prompt }
if ([string]::IsNullOrWhiteSpace($title)) { $title = "Avalon Seed" }

$seed = [ordered]@{
  id = "seed-$ts"
  title = $title
  tags = @('isekai?','tone-balanced','genre-fantasy+sci-fi')
  isekai = ($Prompt -match '(?i)\bisekai\b')
  dnd_compatible = $true
  safety = @{ content_maturity = 'pg-13' }
  protagonist_archetype = 'Explorer'
  starter_hook = if([string]::IsNullOrWhiteSpace($Prompt)) { 'A threshold opens where it should not.' } else { $Prompt }
  conflict = 'rival claims over a threshold'
  language_notes = @('vowel harmony','river-themed idioms')
  pillars = @{
    magic_system = $magicSystems[ (Get-Random -Minimum 0 -Maximum $magicSystems.Count) ]
    tech_level    = $techLevels[ (Get-Random -Minimum 0 -Maximum $techLevels.Count) ]
    travel        = $travels[ (Get-Random -Minimum 0 -Maximum $travels.Count) ]
  }
  cosmology = @{
    planar_topology = $topologies[ (Get-Random -Minimum 0 -Maximum $topologies.Count) ]
    portals = 'thresholds appear at predictable hours'
  }
  factions = @(
    $factions2[ (Get-Random -Minimum 0 -Maximum $factions2.Count) ],
    $factions2[ (Get-Random -Minimum 0 -Maximum $factions2.Count) ]
  )
}

# Optional: use llm-bridge to refine seed if key present and not forced fallback
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $req = @"
You are Alexandria, generating a concise world seed. Given the user prompt (may be empty), return ONLY compact JSON with keys:
{
  "title": "...",
  "protagonist_archetype": "...",
  "starter_hook": "one sentence",
  "conflict": "short phrase",
  "pillars": { "magic_system": "...", "tech_level": "...", "travel": "..." },
  "cosmology": { "planar_topology": "...", "portals": "..." },
  "factions": [ { "name": "...", "motif": "...", "goal": "..." }, { "name": "...", "motif": "...", "goal": "..." } ],
  "tags": ["tag1","tag2"]
}
Prompt:
$Prompt
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.worldseed.json"
  try {
    & $bridge -Prompt $req -OutFile $tmp -DryRun:$false
    $j = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 80
    if ($j) {
      if ($j.title) { $seed.title = [string]$j.title }
      if ($j.protagonist_archetype) { $seed.protagonist_archetype = [string]$j.protagonist_archetype }
      if ($j.starter_hook) { $seed.starter_hook = [string]$j.starter_hook }
      if ($j.conflict) { $seed.conflict = [string]$j.conflict }
      if ($j.pillars) { $seed.pillars = $j.pillars }
      if ($j.cosmology) { $seed.cosmology = $j.cosmology }
      if ($j.factions) { $seed.factions = $j.factions }
      if ($j.tags) { $seed.tags = @($j.tags | ForEach-Object { [string]$_ }) }
    }
  } catch {
    # ignore, keep deterministic defaults
  }
}

# Write seed file
$name = "seed-" + $ts + "-" + (Slug $seed.title) + ".json"
$path = Join-Path $worldsDir $name
($seed | ConvertTo-Json -Depth 200) | Set-Content -Path $path -Encoding utf8NoBOM

Write-Host ("Seed written: " + ("/apps/alexandria/worlds/" + $name))
exit 0
