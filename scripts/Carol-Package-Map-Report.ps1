param(
  [string]$OutFile="pages/apps/carol/plans/packages-missing.json",
  [string]$ShoppingFile="pages/apps/carol/plans/shopping-extracted.json",
  [string]$PackageMap="pages/apps/carol/packages/us.json"
)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$outAbs = Join-Path $root $OutFile
$sfAbs = Join-Path $root $ShoppingFile
$mapAbs = Join-Path $root $PackageMap

if(-not (Test-Path $sfAbs)){ Write-Error "No shopping-extracted.json found or empty. Run Extract first."; exit 1 }
if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }

$items = (Get-Content -Raw -Path $sfAbs | ConvertFrom-Json).items
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

function Find-Sku([string]$name){
  if([string]::IsNullOrWhiteSpace($name)){ return $null }
  $k = $name.ToLowerInvariant()
  if($map.ingredient_map.PSObject.Properties.Name -contains $k){ return [string]$map.ingredient_map.$k }
  foreach($kk in $map.ingredient_map.PSObject.Properties.Name){ if($k -like "*$kk*"){ return [string]$map.ingredient_map.$kk } }
  return $null
}

$missing = @()
foreach($it in $items){
  $n = [string]$it.name; if([string]::IsNullOrWhiteSpace($n)){ continue }
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
