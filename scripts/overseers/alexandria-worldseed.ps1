[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Title="",
  [string]$Prompt="",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return "world" } $t = ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower(); if ($t.Length -gt 80) { $t = $t.Substring(0,80) } return $t }
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

# Load choices (best-effort)
$choices = $null
$choicesPath = Join-Path $RepoRoot "pages/apps/alexandria/knowledge/choices.json"
if (Test-Path $choicesPath) { try { $choices = Get-Content -Raw -Path $choicesPath | ConvertFrom-Json -Depth 100 } catch { $choices = $null } }

function Pick([object[]]$arr, [string]$fallback){ if($arr -and $arr.Count -gt 0){ return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] } return $fallback }

# Defaults if no choices
$magicSystems = @('ritual-magic','runic-tech','spirit-currency','celestial-contracts','bioluminal-weaving')
$techLevels   = @('medieval','clockwork','industrial','diesel','digital','fusion','mythic')
$travels      = @('portals','skyships','dream-walking','river-gates','starlight-bridges')
$topologies   = @('nested-rings','world-tree','shattered-archipelago','spiral-tower','clockwork-spheres')

# Build title
function TitleFromPrompt([string]$p){ if ([string]::IsNullOrWhiteSpace($p)) { return $null } $p = ($p -replace '\s+',' ').Trim(); $words = $p.Split(' '); $take = [Math]::Min(6, $words.Length); $t = [string]::Join(' ', $words[0..($take-1)]); return ($t.Substring(0,1).ToUpper()+$t.Substring(1)) }
$ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$title = if(-not [string]::IsNullOrWhiteSpace($Title)) { $Title } else { TitleFromPrompt $Prompt }
if ([string]::IsNullOrWhiteSpace($title)) { $title = "Avalon Seed" }

# Choices-backed picks
$magic_pick = if($choices) { Pick $choices.magic_schools 'ritual-magic' } else { $magicSystems[(Get-Random -Minimum 0 -Maximum $magicSystems.Count)] }
$tech_pick  = if($choices) { Pick $choices.tech_levels 'medieval' } else { $techLevels[(Get-Random -Minimum 0 -Maximum $techLevels.Count)] }
$travel_pick= if($choices) { Pick $choices.travel_modes 'portals' } else { $travels[(Get-Random -Minimum 0 -Maximum $travels.Count)] }
$topo_pick  = if($choices) { Pick $choices.planar_topologies 'nested-rings' } else { $topologies[(Get-Random -Minimum 0 -Maximum $topologies.Count)] }
$currency   = if($choices) { Pick $choices.currencies 'lantern tokens' } else { 'lantern tokens' }
$culture    = if($choices) { Pick $choices.cultures 'riverfolk' } else { 'riverfolk' }

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
  culture = $culture
  economy = @{ primary_currency = $currency }
  pillars = @{ magic_system = $magic_pick; tech_level = $tech_pick; travel = $travel_pick }
  cosmology = @{ planar_topology = $topo_pick; portals = 'thresholds appear at predictable hours' }
  factions = @(
    @{ name='Order of Lanterns'; motif='guidance'; goal='contain the night' },
    @{ name='Mirror Syndicate'; motif='reflection'; goal='exploit thresholds' }
  )
}

# Optional LLM refinement (non-fatal)
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $req = @"
You are Alexandria, generating a concise world seed from a prompt and a library of choices (lists). Keep keys as provided, return ONLY compact JSON.
Prompt:
$Prompt
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.worldseed.json"
  try {
    & $bridge -Prompt $req -OutFile $tmp -DryRun:$false
    $j = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 80
    if ($j) {
      foreach($k in @('title','protagonist_archetype','starter_hook','conflict')){ if($j.$k){ $seed.$k = [string]$j.$k } }
      if ($j.pillars){ $seed.pillars = $j.pillars }
      if ($j.cosmology){ $seed.cosmology = $j.cosmology }
      if ($j.factions){ $seed.factions = $j.factions }
      if ($j.tags){ $seed.tags = @($j.tags | ForEach-Object { [string]$_ }) }
    }
  } catch { Write-Warning "LLM bridge unavailable; using fallback picks." }
}

$name = "seed-" + $ts + "-" + (Slug $seed.title) + ".json"
$path = Join-Path $worldsDir $name
($seed | ConvertTo-Json -Depth 100) | Set-Content -Path $path -Encoding utf8NoBOM
Write-Host ("Seed written: /apps/alexandria/worlds/" + $name)
exit 0
