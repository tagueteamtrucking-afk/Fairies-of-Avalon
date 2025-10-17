param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$PackageMap="pages/apps/carol/packages/us.json",
  [string]$OutFile="pages/apps/carol/plans/packages-missing.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $root $PlansDir
$mapAbs = Join-Path $root $PackageMap
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

# find a shopping source
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending
if(-not $files){ Write-Error "No plan JSON files in $plansAbs"; exit 1 }

$shopping = @()
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
    if($j.shopping){ $shopping = $j.shopping }
    elseif($j.menu -and $j.menu.shopping){ $shopping = $j.menu.shopping }
    elseif($j.items){ $shopping = $j.items }
  } catch { continue }
  if($shopping.Count -gt 0){ break }
}
if($shopping.Count -eq 0){ Write-Error "Could not locate a shopping array in plan JSONs under $plansAbs"; exit 1 }

function Find-Sku([string]$name){
  if([string]::IsNullOrWhiteSpace($name)){ return $null }
  $k = $name.ToLowerInvariant()
  if($map.ingredient_map.PSObject.Properties.Name -contains $k){ return [string]$map.ingredient_map.$k }
  foreach($kk in $map.ingredient_map.PSObject.Properties.Name){
    if($k -like "*$kk*"){ return [string]$map.ingredient_map.$kk }
  }
  return $null
}

$missing = @()
foreach($it in $shopping){
  $n = [string]$it.name
  if([string]::IsNullOrWhiteSpace($n)){ continue }
  $sku = Find-Sku $n
  if(-not $sku){
    $example = ('"{0}": "<sku_key>"' -f $n.ToLowerInvariant())
    $missing += @{ name=$n; suggestion="Add to ingredient_map"; example=$example }
  }
}

$report = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; missing=$missing }
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($report | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Wrote $OutFile with $($missing.Count) unmapped ingredients."
