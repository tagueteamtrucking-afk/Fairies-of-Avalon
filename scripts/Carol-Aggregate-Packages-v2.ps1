param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$PackageMap="pages/apps/carol/packages/us.json",
  [string]$OutFile="pages/apps/carol/plans/shopping-quantized.json",
  [int]$Persons=2
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $root $PlansDir
$mapAbs = Join-Path $root $PackageMap
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

# find a shopping source in plans dir
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending
if(-not $files){ Write-Error "No plan JSON files in $plansAbs"; exit 1 }

$shopping = @()
$chosen = $null
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
    if($j.shopping){ $shopping = $j.shopping; $chosen=$f; break }
    elseif($j.menu -and $j.menu.shopping){ $shopping = $j.menu.shopping; $chosen=$f; break }
    elseif($j.items){ $shopping = $j.items; $chosen=$f; break }
  } catch { continue }
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
foreach($it in $shopping){
  $n = [string]$it.name
  if([string]::IsNullOrWhiteSpace($n)){ continue }
  $qty = 0.0
  $u = ""
  # normalize quantity
  if($it.qty){ $qty = [double]$it.qty }
  elseif($it.quantity){ $qty = [double]$it.quantity }
  if($it.unit){ $u = [string]$it.unit }
  elseif($it.units){ $u = [string]$it.units }

  # multiply by persons
  $qtyTotal = $qty * [double]$Persons

  if(-not $need.ContainsKey($n)){ $need[$n] = @{ qty = 0.0; unit = $u } }
  $need[$n].qty += $qtyTotal
  if([string]::IsNullOrWhiteSpace($need[$n].unit) -and -not [string]::IsNullOrWhiteSpace($u)){ $need[$n].unit = $u }
}

# Convert to packages by sku
$out = @{
  updated = (Get-Date).ToUniversalTime().ToString('s')+'Z';
  source_plan = $chosen.Name;
  persons = $Persons;
  items = @();
  notes = @()
}

foreach($k in $need.Keys){
  $entry = $need[$k]
  $sku = Find-Sku $k
  $ozNeed = $null
  $flOzNeed = $null
  $unit = ($entry.unit ?? "").ToLowerInvariant()

  # unit conversions where possible
  if($unit -in @("tbsp","tablespoon","tablespoons")){
    $ozNeed = TbspToOz $k $entry.qty
  } elseif($unit -in @("cup","cups")){
    # prefer dry mass conversion for mapped items; else fallback to fl oz
    $try = CupsToOz $k $entry.qty
    if($try -ne $null){ $ozNeed = $try } else { $flOzNeed = CupsToFlOz $entry.qty }
  } elseif($unit -in @("oz","ounce","ounces")){
    $ozNeed = [double]$entry.qty
  } elseif($unit -in @("fl oz","floz","fluid_ounce","fluid_ounces")){
    $flOzNeed = [double]$entry.qty
  } elseif($unit -in @("can","cans","pouch","pouches","bag","bags","loaf","loaves")){
    # treat as package units already
    $out.items += @{ name=$k; unit=$unit; packages=[math]::Ceiling([double]$entry.qty); package_size=null; sku=$sku }
    continue
  } else {
    # unknown unit: emit raw, ask user to map
    $out.items += @{ name=$k; unit=$unit; raw_qty=[double]$entry.qty; sku=$sku; warning="Unrecognized unit; add conversion or standardize plan units" }
    continue
  }

  if(-not $sku){
    $out.items += @{ name=$k; unit=$unit; estimate_oz=$ozNeed; estimate_fl_oz=$flOzNeed; warning="No SKU mapping. Add to ingredient_map." }
    continue
  }

  $skuNode = $map.skus.$sku
  if($null -eq $skuNode){ 
    $out.items += @{ name=$k; unit=$unit; estimate_oz=$ozNeed; estimate_fl_oz=$flOzNeed; sku=$sku; warning="SKU not defined in map.skus" }
    continue
  }

  $packs = @()
  if($ozNeed -ne $null -and $skuNode.packages_oz){ 
    $best = $skuNode.packages_oz | Sort-Object { $_ }
    $need = [double]$ozNeed
    $count = [math]::Ceiling($need / [double]$best[-1])
    if($count -lt 1){ $count = 1 }
    $packs += @{ size_oz=$best[-1]; count=$count }
  } elseif($flOzNeed -ne $null -and $skuNode.packages_fl_oz){
    $best = $skuNode.packages_fl_oz | Sort-Object { $_ }
    $need = [double]$flOzNeed
    $count = [math]::Ceiling($need / [double]$best[-1])
    if($count -lt 1){ $count = 1 }
    $packs += @{ size_fl_oz=$best[-1]; count=$count }
  } elseif($skuNode.packages_oz){
    # treat input as oz implicitly
    $best = $skuNode.packages_oz | Sort-Object { $_ }
    $need = [double]$entry.qty
    $count = [math]::Ceiling($need / [double]$best[-1])
    if($count -lt 1){ $count = 1 }
    $packs += @{ size_oz=$best[-1]; count=$count }
  } else {
    $out.items += @{ name=$k; unit=$unit; sku=$sku; warning="No compatible package sizes for computed units" }
    continue
  }

  $out.items += @{ name=$k; unit=$unit; sku=$sku; packages=$packs }
}

# Write output
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Quantized shopping -> $OutFile (persons=$Persons)"
