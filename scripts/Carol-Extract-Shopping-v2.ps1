param([string]$PlansDir="pages/apps/carol/plans",[string]$OutFile="pages/apps/carol/plans/shopping-extracted.json")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $here $PlansDir
$outAbs = Join-Path $here $OutFile
if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
$items = @()
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Where-Object {
  $_.Name -notmatch "^shopping-(extracted|quantized)\.json$" -and $_.Name -notmatch "^packages-missing\.json$"
}
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
  } catch { continue }
  if($j.shopping){ $items += @($j.shopping); continue }
  if($j.menu -and $j.menu.shopping){ $items += @($j.menu.shopping); continue }
  if($j.menu -and $j.menu.days){
    foreach($d in $j.menu.days){
      if($d.shopping){ $items += @($d.shopping) }
    }
  }
}
$flat = @()
foreach($arr in $items){
  foreach($x in $arr){
    $n = $x.name; if(-not $n){ $n = $x.item }
    $u = $x.unit; $q = $x.qty
    if($n -and $q){
      $flat += @{ name=$n; qty=[double]$q; unit=$u }
    }
  }
}
$out = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$flat }
$dir = Split-Path -Parent $outAbs
if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
Write-Host "Wrote $OutFile with $($flat.Count) items."
