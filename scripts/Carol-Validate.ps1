$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root 'pages/apps/carol/plans'
if (-not (Test-Path $dir)) { Write-Host "No Carol plans."; exit 0 }
$bad=@(); $warn=@()
Get-ChildItem -File $dir -Filter *.json | ForEach-Object {
  $p = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json
  if (-not $p.sources -or $p.sources.Count -lt 1) { $bad += @{file=$_.Name; issue="no-sources"} }
  foreach($d in $p.days){
    $sodium = 0; $sugar_g = 0; $kcal = 0; $fiber = 0
    foreach($m in $d.menus){ $sodium += ($m.sodium_mg|Measure-Object -Sum).Sum; $sugar_g += ($m.added_sugars_g|Measure-Object -Sum).Sum; $kcal += ($m.est_kcal|Measure-Object -Sum).Sum; $fiber += ($m.fiber_g|Measure-Object -Sum).Sum }
    if ($sodium -gt 2000) { $bad += @{file=$_.Name; day=$d.day; issue=("sodium>"+$sodium)} }
    if ($kcal -gt 0) {
      $sugar_pct = (($sugar_g*4.0)/[double]$kcal)*100.0
      if ($sugar_pct -gt 10.0) { $bad += @{file=$_.Name; day=$d.day; issue=("added_sugars%="+[math]::Round($sugar_pct,1))} }
    } else { $warn += @{file=$_.Name; day=$d.day; issue="missing_kcal_for_%calc"} }
    if ($fiber -lt 25) { $warn += @{file=$_.Name; day=$d.day; issue=("fiber_low="+$fiber)} }
  }
}
if ($bad.Count -gt 0) { Write-Error ("Carol validate failed: " + ($bad | ConvertTo-Json -Depth 6)); exit 1 }
Write-Host ("Carol validate OK. Warnings: " + ($warn | ConvertTo-Json -Depth 6))
