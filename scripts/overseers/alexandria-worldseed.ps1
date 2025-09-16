[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Title="Avalon World",
  [switch]$Isekai,
  [switch]$DndCompatible
)
$ErrorActionPreference='Stop'

function Slug([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "world" }
  $t = ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower()
  return $t.Substring(0, [Math]::Min(80, $t.Length))
}

# Ensure worlds folder
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null

# Seed attributes (deterministic-ish fallback pools)
$tags = @('isekai','adventure','balanced','mystery','futuristic-fantasy')
$magicSystems = @('ritual-magic','songcraft','blood‑binding','glyph engines','dreamweaving')
$techLevels = @('medieval','clockwork','diesel','digital','fusion')
$travelModes = @('portals','skyships','ley‑ferries','mirror‑steps','astral rails')
$topologies = @('layered spheres','archipelago planes','world‑tree','clockwork orrery','shifting labyrinth')

$factions = @(
  @{ name='Order of Lanterns'; motif='guidance'; goal='contain breaches' },
  @{ name='Veil Cartel'; motif='secrecy'; goal='monopolize crossings' }
)

# Compose seed
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss")
$title = if([string]::IsNullOrWhiteSpace($Title)) { "Avalon World" } else { $Title }
$id    = "seed-$stamp-" + (Slug $title)

$seed = [pscustomobject]@{
  id = $id
  title = $title
  isekai = [bool]$Isekai
  dnd_compatible = [bool]$DndCompatible
  tags = $tags
  starter_hook = "A forbidden crossing leaves a debt that must be repaid."
  protagonist_archetype = "reluctant guide"
  safety = @{ content_maturity = "pg-13" }
  pillars = @{
    magic_system = $magicSystems[(Get-Random -Minimum 0 -Maximum $magicSystems.Count)]
    tech_level   = $techLevels[(Get-Random -Minimum 0 -Maximum $techLevels.Count)]
    travel       = $travelModes[(Get-Random -Minimum 0 -Maximum $travelModes.Count)]
  }
  cosmology = @{
    planar_topology = $topologies[(Get-Random -Minimum 0 -Maximum $topologies.Count)]
    portals = "waystones, veils, and engineered arches"
  }
  factions = @(
    [pscustomobject]$factions[0],
    [pscustomobject]$factions[1]
  )
  conflict = "control of crossings vs free passage"
  language_notes = @("trade pidgin with lantern glyphs")
}

# Write file
$outName = "seed-$stamp-" + (Slug $title) + ".json"
$path = Join-Path $worldsDir $outName
($seed | ConvertTo-Json -Depth 40) | Set-Content -Path $path -Encoding utf8NoBOM

Write-Host "Seed written: /apps/alexandria/worlds/$outName"
exit 0
