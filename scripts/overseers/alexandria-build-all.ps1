[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Title="",
  [string]$Prompt="",
  [int]$Events=7,
  [int]$NPCs=12,
  [int]$Regions=5,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
$root = (Resolve-Path $RepoRoot).Path
$tools = Join-Path $RepoRoot "scripts/overseers"

# Ensure choices-derived taxonomies
& (Join-Path $tools "alexandria-choices-prepare.ps1") -RepoRoot $RepoRoot

# World seed
& (Join-Path $tools "alexandria-worldseed.ps1") -RepoRoot $RepoRoot -Title $Title -Prompt $Prompt -ForceFallback:$ForceFallback

# Lore Bible
& (Join-Path $tools "alexandria-lore-bible.ps1") -RepoRoot $RepoRoot -ForceFallback:$ForceFallback

# Timeline
& (Join-Path $tools "alexandria-timeline.ps1") -RepoRoot $RepoRoot -Count $Events -ForceFallback:$ForceFallback

# NPC Codex
& (Join-Path $tools "alexandria-npc-codex.ps1") -RepoRoot $RepoRoot -Count $NPCs -ForceFallback:$ForceFallback

# Regional Atlas
& (Join-Path $tools "alexandria-atlas.ps1") -RepoRoot $RepoRoot -Regions $Regions -ForceFallback:$ForceFallback

# Export zip
& (Join-Path $tools "alexandria-export.ps1") -RepoRoot $RepoRoot

Write-Host "Build-All completed."
exit 0
