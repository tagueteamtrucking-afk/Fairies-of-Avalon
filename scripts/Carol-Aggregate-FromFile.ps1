param(
  [string]$ShoppingFile="pages/apps/carol/plans/shopping-extracted.json",
  [string]$PackageMap="pages/apps/carol/packages/us.json",
  [string]$OutFile="pages/apps/carol/plans/shopping-quantized.json",
  [int]$Persons=2
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$shAbs = Join-Path $root $ShoppingFile
$mapAbs = Join-Path $root $PackageMap
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $shAbs)){ Write-Error "Shopping file not found at $shAbs"; exit 1 }
if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }

try{ $shoppingDoc = Get-Content -Raw -Path $shAbs | ConvertFrom-Json } catch { Write-Error "Invalid JSON in $ShoppingFile"; exit 1 }
$items = @()
if($shoppingDoc.items){ $items = $shoppingDoc.items } else { $items = $shoppingDoc }
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

function Find-Sku([string]$name){
  if([string]::IsNullOrWhiteSpace($name)){ return $null }
  $k = $name.ToLowerInvariant()
  if($map.ingredient_map.PSObject.Properties.Name -contains $k){ return [string]$map.ingredient_map.$k }
  foreach($kk in $map.ingredient_map.PSObject.Properties.Name){
    if($k -like "*$kk*"){ return [string]$map.ingredient_map.$kk }
  }
  return $null
}

function TbspToOz([string]$name,[double]$tbsp){
  $k = $name.ToLowerInvariant()
  $gpt = $map.units.tbsp_to_g.$k
  if($null -eq $gpt){ return $null }
  $g = $tbsp * [double]$gpt
  return $g / 28.3495
}
function CupsToOz([string]$name,[double]$cups){
  $k = $name.ToLowerInvariant()
  $gpc = $map.units.cup_to_g.$k
  if($null -eq $gpc){ return $null }
  $g = $cups * [double]$gpc
  return $g / 28.3495
}
function CupsToFlOz([double]$cups){ return $cups * [double]$map.units.fluid_oz_per_cup }

# Aggregate
$need = @{}
foreach($it in $items){
  $n = [string]$it.name
  if([string]::IsNullOrWhiteSpace($n)){ continue }
  $q = 0.0; $u = ""
  if($it.qty){ $q = [double]$it.qty } elseif($it.quantity){ $q = [double]$it.quantity }
  if($it.unit){ $u = [string]$it.unit } elseif($it.units){ $u = [string]$it.units }
  $q *= [double]$Persons
  if(-not $need.ContainsKey($n)){ $need[$n] = @{ qty=0.0; unit=$u } }
  $need[$n].qty += $q
  if([string]::IsNullOrWhiteSpace($need[$n].unit) -and -not [string]::IsNullOrWhiteSpace($u)){ $need[$n].unit = $u }
}

$out = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z';
  source=$ShoppingFile; persons=$Persons; items=@(); notes=@()
}

foreach($k in $need.Keys){
  $entry = $need[$k]; $u = ($entry.unit ?? "").ToLowerInvariant()
  $sku = Find-Sku $k
  $ozNeed = $null; $flOzNeed = $null
  if($u -in @("tbsp","tablespoon","tablespoons")){ $ozNeed = TbspToOz $k $entry.qty }
  elseif($u -in @("cup","cups")){ $ozNeed = CupsToOz $k $entry.qty; if($ozNeed -eq $null){ $flOzNeed = CupsToFlOz $entry.qty } }
  elseif($u -in @("oz","ounce","ounces")){ $ozNeed = [double]$entry.qty }
  elseif($u -in @("fl oz","floz","fluid_ounce","fluid_ounces")){ $flOzNeed = [double]$entry.qty }
  elseif($u -in @("can","cans","pouch","pouches","bag","bags","loaf","loaves")){
    $out.items += @{ name=$k; unit=$u; packages=[math]::Ceiling([double]$entry.qty); package_size=$null; sku=$sku }
    continue
  } else {
    $out.items += @{ name=$k; unit=$u; raw_qty=[double]$entry.qty; sku=$sku; warning="Unknown unit; standardize or add conversion" }
    continue
  }

  if(-not $sku){ $out.items += @{ name=$k; unit=$u; estimate_oz=$ozNeed; estimate_fl_oz=$flOzNeed; warning="No SKU mapping. Add to ingredient_map." }; continue }
  $skuNode = $map.skus.$sku
  if($null -eq $skuNode){ $out.items += @{ name=$k; unit=$u; estimate_oz=$ozNeed; estimate_fl_oz=$flOzNeed; sku=$sku; warning="SKU not defined" }; continue }

  if($ozNeed -ne $null -and $skuNode.packages_oz){
    $sizes = $skuNode.packages_oz | Sort-Object { $_ }
    $count = [math]::Ceiling($ozNeed / [double]$sizes[-1])
    if($count -lt 1){ $count = 1 }
    $out.items += @{ name=$k; unit=$u; sku=$sku; packages=@(@{ size_oz=$sizes[-1]; count=$count }) }
  } elseif($flOzNeed -ne $null -and $skuNode.packages_fl_oz){
    $sizes = $skuNode.packages_fl_oz | Sort-Object { $_ }
    $count = [math]::Ceiling($flOzNeed / [double]$sizes[-1])
    if($count -lt 1){ $count = 1 }
    $out.items += @{ name=$k; unit=$u; sku=$sku; packages=@(@{ size_fl_oz=$sizes[-1]; count=$count }) }
  } else {
    $out.items += @{ name=$k; unit=$u; sku=$sku; warning="No compatible package sizes for units" }
  }
}

$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Quantized shopping from file -> $OutFile (persons=$Persons)"
