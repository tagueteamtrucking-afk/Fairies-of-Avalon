# White Star — Overseer Experience & Alignment
# Purpose: fast, safe repo audit + optional cleanup (no secrets, no prompts).

[CmdletBinding()]
param(
  [ValidateSet('all','scan','report','cleanup')]
  [string]$Action = 'all',
  [switch]$Mutate
)

$ErrorActionPreference = 'Stop'

function Get-ProjectRoot { return (Resolve-Path "$PSScriptRoot\..\..\..").Path }

$Root   = Get-ProjectRoot
$OutDir = Join-Path $Root 'apps\overseers\out'
$LogDir = Join-Path $Root 'apps\overseers\log'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Get-RepoFiles {
  param([string]$Base)
  Get-ChildItem -LiteralPath $Base -Recurse -Force -File |
    Where-Object { $_.FullName -notmatch '[\\\/]\.git([\\\/]|$)' }  # fixed regex
}

function Ensure-CanonicalAssetTree {
  $canon = @(
    'asset\models\wingless',
    'asset\models\with-wings',
    'asset\wings\textures',
    'asset\textures',
    'pages'
  )
  foreach ($p in $canon) { New-Item -ItemType Directory -Force -Path (Join-Path $Root $p) | Out-Null }
}

function Analyze-Assets {
  param([string]$Base)

  Ensure-CanonicalAssetTree

  $findings = [ordered]@{ strays=@(); actions=@(); warnings=@() }

  $topModels   = Join-Path $Base 'models\avatars'
  $topTextures = Join-Path $Base 'textures'
  $topWings    = Join-Path $Base 'wings'
  $rootWIHtml  = Join-Path $Base 'wings-importer.html'
  $rootWIJs    = Join-Path $Base 'wings-importer.js'

  if (Test-Path $topModels)   { $findings.strays += 'Found top-level "models/avatars" → should be asset/models/wingless.' }
  if (Test-Path $topTextures) { $findings.strays += 'Found top-level "textures" → should be asset/textures.' }
  if (Test-Path $topWings)    { $findings.strays += 'Found top-level "wings" → should be asset/wings.' }
  if (Test-Path $rootWIHtml)  { $findings.strays += 'Found root "wings-importer.html" → should be pages/wings-importer.html.' }
  if (Test-Path $rootWIJs)    { $findings.strays += 'Found root "wings-importer.js" → should be pages/wings-importer.js.' }

  if (Test-Path $topModels)   { $findings.actions += @{ move=$topModels; to=(Join-Path $Base 'asset\models\wingless') } }
  if (Test-Path $topTextures) { $findings.actions += @{ move=$topTextures; to=(Join-Path $Base 'asset\textures') } }
  if (Test-Path $topWings)    { $findings.actions += @{ move=$topWings; to=(Join-Path $Base 'asset\wings') } }
  if (Test-Path $rootWIHtml)  { $findings.actions += @{ move=$rootWIHtml; to=(Join-Path $Base 'pages') } }
  if (Test-Path $rootWIJs)    { $findings.actions += @{ move=$rootWIJs; to=(Join-Path $Base 'pages') } }

  return $findings
}

function Execute-Moves {
  param($Actions)
  foreach ($a in $Actions) {
    if (-not (Test-Path $a.move)) { continue }
    $dest = $a.to
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $item = Get-Item -LiteralPath $a.move
    if ($item.PSIsContainer) {
      Write-Host "Moving DIR `"$($a.move)`" -> `"$dest`""
      robocopy $a.move $dest /E /MOVE /NFL /NDL /NJH /NJS /NP | Out-Null
    } else {
      Write-Host "Moving FILE `"$($a.move)`" -> `"$dest`""
      Move-Item -LiteralPath $a.move -Destination $dest -Force
    }
  }
}

function Write-Json { param($Object,[string]$Path); $Object | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8 -NoNewline }

$report = [ordered]@{
  ts=(Get-Date).ToString('s')+'Z'; actor='white-star'; action=$Action; mutate=[bool]$Mutate
  status='ok'; file_count=0; warnings=@(); suggestions=@()
}

try {
  $files = Get-RepoFiles -Base $Root
  $report.file_count = $files.Count

  $analysis = Analyze-Assets -Base $Root
  $report.suggestions = $analysis.actions
  if ($analysis.strays.Count -gt 0) { $report.warnings = $analysis.strays }

  if ($Action -eq 'cleanup' -and $Mutate) { Execute-Moves -Actions $analysis.actions }

} catch {
  $report.status = 'error'
  $report.error  = ($_ | Out-String)
} finally {
  $outPath = Join-Path $OutDir 'white-star.report.json'
  Write-Json -Object $report -Path $outPath
  Write-Host "White Star report -> $outPath"
}

if ($report.status -eq 'ok') { exit 0 } else { exit 1 }
