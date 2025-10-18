param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$PackageMap="pages/apps/carol/packages/us.json"
)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
pwsh -File (Join-Path $here "Carol-Extract-Shopping-v2.ps1") -PlansDir $PlansDir -OutFile (Join-Path $PlansDir "shopping-extracted.json")
pwsh -File (Join-Path $here "Carol-Aggregate-Packages-v2.ps1") -PlansDir $PlansDir -PackageMap $PackageMap -OutFile (Join-Path $PlansDir "shopping-quantized.json") -Persons 2
pwsh -File (Join-Path $here "Carol-Build-Pointer.ps1") -PlansDir $PlansDir -OutFile "pages/apps/carol/index.json"
Write-Host "Carol refresh complete."
