param(
  [string]$PlanFile = "pages/apps/carol/plans/twoperson-2wk-merged.json",
  [string]$OutFile  = "pages/apps/carol/plans/shopping-extracted.json",
  [int]$Persons     = 2
)
$ErrorActionPreference="Stop"
if(!(Test-Path $PlanFile)){ throw "Plan file not found: $PlanFile" }
$j = Get-Content $PlanFile -Raw | ConvertFrom-Json

$acc = @{}  # ingredient -> list of {qty, unit}
foreach($d in $j.days){
  foreach($ev in $d.events){
    foreach($it in $ev.items){
      $key = ($it.ingredient+"").Trim().ToLower()
      if(-not $acc.ContainsKey($key)){ $acc[$key] = @() }
      $q = [double]$it.quantity
      if($q -and $Persons -gt 0){ $q = $q * $Persons } # 2 persons scaling
      $acc[$key] += [PSCustomObject]@{ qty=$q; unit=($it.unit+"" ) }
    }
  }
}
$rows = @()
foreach($k in $acc.Keys){
  $byUnit = @{}
  foreach($x in $acc[$k]){
    $u = ($x.unit+"").ToLower()
    if(-not $byUnit.ContainsKey($u)){ $byUnit[$u]=0.0 }
    $byUnit[$u] += [double]$x.qty
  }
  foreach($u in $byUnit.Keys){
    $rows += [PSCustomObject]@{ ingredient=$k; unit=$u; total=[math]::Round($byUnit[$u],3) }
  }
}
$payload = [PSCustomObject]@{
  updated = (Get-Date).ToString("o")
  from_plan = $PlanFile
  persons = $Persons
  items = $rows | Sort-Object ingredient, unit
}
$dir = Split-Path -Parent $OutFile
if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "Extracted shopping -> $OutFile with $($rows.Count) lines."
