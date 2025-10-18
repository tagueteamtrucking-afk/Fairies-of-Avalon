param(
  [string]$KeepListFile="config/keep-lists/workflows-keep.json",
  [switch]$Delete,
  [switch]$VerboseLog
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keepAbs = Join-Path $root $KeepListFile
$wfDir = Join-Path $root ".github/workflows"

if(-not (Test-Path $wfDir)){ Write-Error "No .github/workflows directory found"; exit 1 }
if(-not (Test-Path $keepAbs)){ Write-Error "Keep-list not found: $keepAbs"; exit 1 }

try{ $keep = Get-Content -Raw -Path $keepAbs | ConvertFrom-Json } catch { Write-Error "Invalid JSON in $KeepListFile"; exit 1 }
$keepNames = @($keep.workflows)

$all = Get-ChildItem -Path $wfDir -File -Include *.yml,*.yaml -Recurse
$toDelete = @()
foreach($f in $all){
  if($keepNames -notcontains $f.Name){
    $toDelete += $f.FullName
  }
}

if($VerboseLog){ Write-Host "Will keep: $($keepNames -join ', ')" }
Write-Host "Found $($all.Count) workflow files. Candidates to delete: $($toDelete.Count)"
if(-not $Delete){
  $report = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; keep=$keepNames; delete=$toDelete }
  $out = Join-Path $root "memory-history/workflow-clean-preview.json"
  [IO.File]::WriteAllText($out, ($report | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
  Write-Host "Dry-run. Wrote preview to $out. Re-run with -Delete to remove."
  exit 0
}

foreach($p in $toDelete){
  Remove-Item -Path $p -Force
  if($VerboseLog){ Write-Host "Deleted $p" }
}
Write-Host "Deleted $($toDelete.Count) workflow files."
