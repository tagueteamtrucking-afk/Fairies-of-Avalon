# White Star — Overseer Experience & Alignment
# Purpose: fast, safe repo audit + optional cleanup (no secrets, no prompts).
# Usage in Actions:
#   pwsh -File "apps/overseers/ai/white-star.ps1" -Action all
#   pwsh -File "apps/overseers/ai/white-star.ps1" -Action cleanup -Mutate

[CmdletBinding()]
param(
  [ValidateSet('all','scan','report','cleanup')]
  [string]$Action = 'all',
  [switch]$Mutate
)

$ErrorActionPreference = 'Stop'

function Get-ProjectRoot {
  # ai/ -> overseers/ -> apps/ -> repo root
  return (Resolve-Path "$PSScriptRoot\..\..\..").Path
}

$Root   = Get-ProjectRoot
$OutDir = (Resolve-Path "$PSScriptRoot\..\out" -ErrorAction SilentlyContinue).Path
$LogDir = (Resolve-Path "$PSScriptRoot\..\log" -ErrorAction SilentlyContinue).Path
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Get-RepoFiles {
  param([string]$Base)
  Get-ChildItem -LiteralPath $Base -Recurse -Force -File |
    # NOTE: robust exclusion for ".git" regardless of slash style
    Where-Object { $_.FullName -notmatch '[\\\/]\.git([\\\/]|$)' }
}

function Ensure-CanonicalAssetTree {
  $canon = @(
    'asset\models\wingless',
    'asset\models\with-wings',
    'asset\wings\textures',
    'asset\textures'
  )
  foreach ($p in $canon) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $p) | Out-Null
  }
}

function Analyze-Assets {
  param([string]$Base)

  Ensure-CanonicalAssetTree

  $findings = [ordered]@{
    strays   = @()
    actions  = @()   # proposed moves
    warnings = @()
  }

  $topModels   = Join-Path $Base 'models\avatars'
  $topTextures = Join-Path $Base 'textures'
  $topWings    = Join-Path $Base 'wings'

  if (Test-Path $topModels)   { $findings.strays += 'Found top-level "models/avatars" (should live under asset/models/wingless).' }
  if (Test-Path $topTextures) { $findings.strays += 'Found top-level "textures" (should live under asset/textures).' }
  if (Test-Path $topWings)    { $findings.strays += 'Found top-level "wings" (should live under asset/wings).' }

  if (Test-Path $topModels) {
    $findings.actions += @{ move = $topModels; to = (Join-Path $Base 'asset\models\wingless') }
  }
  if (Test-Path $topTextures) {
    $findings.actions += @{ move = $topTextures; to = (Join-Path $Base 'asset\textures') }
  }
  if (Test-Path $topWings) {
    $findings.actions += @{ move = $topWings; to = (Join-Path $Base 'asset\wings') }
  }

  return $findings
}

function Execute-Moves {
  param($Actions)
  foreach ($a in $Actions) {
    if (-not (Test-Path $a.move)) { continue }
    New-Item -ItemType Directory -Force -Path $a.to | Out-Null
    Write-Host "Moving `"$($a.move)`" -> `"$($a.to)`""
    # Use robocopy for speed & atomicity on Windows
    robocopy $a.move $a.to /E /MOVE /NFL /NDL /NJH /NJS /NP | Out-Null
  }
}

function Write-Json {
  param($Object, [string]$Path)
  $json = $Object | ConvertTo-Json -Depth 8
  Set-Content -LiteralPath $Path -Encoding UTF8 -NoNewline -Value $json
}

$report = [ordered]@{
  ts          = (Get-Date).ToString('s') + 'Z'
  actor       = 'white-star'
  action      = $Action
  mutate      = [bool]$Mutate
  status      = 'ok'
  file_count  = 0
  warnings    = @()
  suggestions = @()
}

try {
  $files = Get-RepoFiles -Base $Root
  $report.file_count = $files.Count

  $analysis = Analyze-Assets -Base $Root
  $report.suggestions = $analysis.actions
  if ($analysis.strays.Count -gt 0) { $report.warnings = $analysis.strays }

  if ($Action -eq 'cleanup' -and $Mutate) {
    Execute-Moves -Actions $analysis.actions
  }

} catch {
  $report.status = 'error'
  $report.error  = ($_ | Out-String)
} finally {
  $outPath = Join-Path $OutDir 'white-star.report.json'
  Write-Json -Object $report -Path $outPath
  Write-Host "White Star report -> $outPath"
}

if ($report.status -eq 'ok') { exit 0 } else { exit 1 }
