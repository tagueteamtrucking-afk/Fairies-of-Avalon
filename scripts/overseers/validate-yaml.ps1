[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [switch]$WriteReport
)

$ErrorActionPreference='Continue'
try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function Test-YamlFile([string]$path) {
  $ok=$true; $msg=$null
  try {
    $raw = Get-Content -Raw -Path $path -ErrorAction Stop
    # quick tab check
    if ($raw -match "^\t" -or $raw -match "\r\t") {
      throw "Tabs detected (YAML requires spaces)."
    }
    # attempt parse (all docs)
    $null = ConvertFrom-Yaml -Yaml $raw -AllDocuments
  } catch {
    $ok=$false; $msg=($_.Exception.Message)
  }
  [PSCustomObject]@{ path=$path; ok=$ok; message=$msg }
}

$yamlFiles = @(Get-ChildItem $RepoRoot -Recurse -File -Include *.yml,*.yaml)
$results = @(); $errors=0; $memoryBroken=$false
foreach ($f in $yamlFiles) {
  $r = Test-YamlFile $f.FullName
  $results += $r
  if (-not $r.ok) {
    $errors++
    if ($f.Name -eq "Cody's Memory.yaml") { $memoryBroken=$true }
  }
}

$report = [ordered]@{
  scanned = $yamlFiles.Count
  errors  = $errors
  memory_broken = $memoryBroken
  memory_status = "ok"
  when = (Get-Date).ToUniversalTime().ToString("o")
  items = $results
}

if ($memoryBroken) {
  # try automatic restore
  $norm = Join-Path $PSScriptRoot "normalize-memory.ps1"
  if (Test-Path $norm) {
    & $norm -RepoRoot $RepoRoot -AutoRestore
    if ($LASTEXITCODE -eq 0) { $report.memory_status = "restored" } else { $report.memory_status = "restore_failed" }
  } else {
    $report.memory_status = "no_normalizer"
  }
}

if ($WriteReport) {
  $outDir = Join-Path $RepoRoot "pages/apps/overseers"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  ($report | ConvertTo-Json -Depth 8) | Set-Content -Path (Join-Path $outDir "yaml-report.json") -Encoding utf8NoBOM
}

# Never hard-fail; return 0
exit 0
