param([string]$KeepList="config/keep-lists/workflows-keep.json")
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$keepAbs = Join-Path $root $KeepList
if(-not (Test-Path $keepAbs)){ Write-Error "Keep-list not found: $keepAbs"; exit 1 }
$cfg = Get-Content -Raw -Path $keepAbs | ConvertFrom-Json
$keep = New-Object System.Collections.Generic.HashSet[string]
foreach($k in $cfg.keep){ $keep.Add($k) | Out-Null }
$wfDir = Join-Path $root ".github/workflows"
$toRemove = @()
if(Test-Path $wfDir){
  $wfs = Get-ChildItem -Path $wfDir -File -Include *.yml,*.yaml
  foreach($wf in $wfs){
    if(-not $keep.Contains($wf.Name)){
      $toRemove += $wf.FullName
    }
  }
}
if($toRemove.Count -eq 0){ Write-Host "No workflows to remove."; exit 0 }
Write-Host "Removing $($toRemove.Count) workflows not in keep-list..."
foreach($p in $toRemove){ Remove-Item -Path $p -Force }
Write-Host "Done."
