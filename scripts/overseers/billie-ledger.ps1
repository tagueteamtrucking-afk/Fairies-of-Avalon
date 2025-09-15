[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
$outDir = Join-Path $RepoRoot "pages/apps/billie"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$sources = @()
$shopsDir = Join-Path $RepoRoot "pages/shops"
if (Test-Path $shopsDir){
  $files = Get-ChildItem $shopsDir -Recurse -Filter sales.json
  foreach($f in $files){
    try{
      $s = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
      if ($s.total -and $s.name){ $sources += [pscustomobject]@{ name=$s.name; amount=[double]$s.total } }
    }catch{}
  }
}
if ($sources.Count -eq 0){
  $sources = @([pscustomobject]@{ name='Shop A'; amount=0.00 }, [pscustomobject]@{ name='Shop B'; amount=0.00 })
}
$total = ($sources | Measure-Object -Property amount -Sum).Sum
$report = @{ total=[double]$total; sources=$sources; generated=(Get-Date).ToUniversalTime().ToString("s")+'Z' }
($report | ConvertTo-Json -Depth 40) | Set-Content -Path (Join-Path $outDir "revenue.json") -Encoding utf8NoBOM
Write-Host "Revenue aggregated."
exit 0
