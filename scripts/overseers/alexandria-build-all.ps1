param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$Title,
  [string]$Prompt,
  [int]$Events = 7,
  [int]$NPCs = 12,
  [int]$Regions = 5,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
# seed
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-worldseed.ps1') -RepoRoot $RepoRoot -Title $Title -Prompt $Prompt -ForceFallback:$ForceFallback
# find world from latest seed
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
$latest = Get-ChildItem -LiteralPath $worldsDir -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$worldId = ($latest.BaseName.Substring(5))
# others
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-lore-bible.ps1') -RepoRoot $RepoRoot -World $worldId
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-timeline.ps1') -RepoRoot $RepoRoot -World $worldId -Count $Events
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-npc-codex.ps1') -RepoRoot $RepoRoot -World $worldId -Count $NPCs
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-atlas.ps1') -RepoRoot $RepoRoot -World $worldId -Regions $Regions
