param(
  [string]$ShoppingFile="pages/apps/carol/plans/shopping-extracted.json",
  [string]$PackageMap="pages/apps/carol/packages/us.json",
  [string]$OutFile="pages/apps/carol/plans/shopping-quantized.json",
  [int]$Persons=2
)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$sfAbs = Join-Path $root $ShoppingFile
$mapAbs = Join-Path $root $PackageMap
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $sfAbs)){ Write-Error "Shopping file not found at $sfAbs"; exit 1 }
if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }

$doc = Get-Content -Raw -Path $sfAbs | ConvertFrom-Json
$items = $doc.items
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

function Find-Sku([string]$name){
  if([string]::IsNullOrWhiteSpace($name)){ return $null }
  $k = $name.ToLowerInvariant()
  if($map.ingredient_map.PSObject.Properties.Name -contains $k){ return [string]$map.ingredient_map.$k }
  foreach($kk in $map.ingredient_map.PSObject.Properties.Name){ if($k -like "*$kk*"){ return [string]$map.ingredient_map.$kk } }
  return $null
}
function TbspToOz([string]$name,[double]$tbsp){ $k=$name.ToLowerInvariant(); $gpt=$map.units.tbsp_to_g.$k; if($null -eq $gpt){ return $null }; $g=$tbsp*[double]$gpt; return $g/28.3495 }
function CupsToOz([string]$name,[double]$cups){ $k=$name.ToLowerInvariant(); $gpc=$map.units.cup_to_g.$k; if($null -eq $gpc){ return $null }; $g=$cups*[double]$gpc; return $g/28.3495 }
function CupsToFlOz([double]$cups){ return $cups*[double]$map.units.fluid_oz_per_cup }

$need=@{}
foreach($it in $items){
  $n=[string]$it.name; if([string]::IsNullOrWhiteSpace($n)){ continue }
  $q=0.0; $u=""; if($it.qty){ $q=[double]$it.qty } elseif($it.quantity){ $q=[double]$it.quantity }
  if($it.unit){ $u=[string]$it.unit } elseif($it.units){ $u=[string]$it.units }
  $q *= [double]$Persons
  if(-not $need.ContainsKey($n)){ $need[$n]=@{ qty=0.0; unit=$u } }
  $need[$n].qty += $q
  if([string]::IsNullOrWhiteSpace($need[$n].unit) -and -not [string]::IsNullOrWhiteSpace($u)){ $need[$n].unit=$u }
}

$out=@{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; persons=$Persons; source=$ShoppingFile; items=@() }
foreach($k in $need.Keys){
  $e=$need[$k]; $u=($e.unit??"").ToLowerInvariant(); $sku=Find-Sku $k
  $oz=$null; $floz=$null
  if($u -in @("tbsp","tablespoon","tablespoons")){ $oz=TbspToOz $k $e.qty }
  elseif($u -in @("cup","cups")){ $oz=CupsToOz $k $e.qty; if($oz -eq $null){ $floz=CupsToFlOz $e.qty } }
  elseif($u -in @("oz","ounce","ounces")){ $oz=[double]$e.qty }
  elseif($u -in @("fl oz","floz","fluid_ounce","fluid_ounces")){ $floz=[double]$e.qty }
  elseif($u -in @("can","cans","pouch","pouches","bag","bags","loaf","loaves")){
    $out.items += @{ name=$k; unit=$u; packages=[math]::Ceiling([double]$e.qty); sku=$sku }
    continue
  } else {
    $out.items += @{ name=$k; unit=$u; raw_qty=[double]$e.qty; sku=$sku; warning="Unknown unit" }
    continue
  }
  if(-not $sku){ $out.items += @{ name=$k; unit=$u; estimate_oz=$oz; estimate_fl_oz=$floz; warning="No SKU" }; continue }
  $node=$map.skus.$sku
  if($null -eq $node){ $out.items += @{ name=$k; unit=$u; estimate_oz=$oz; estimate_fl_oz=$floz; sku=$sku; warning="SKU node missing" }; continue }
  if($oz -ne $null -and $node.packages_oz){
    $sizes=$node.packages_oz | Sort-Object { $_ }; $count=[math]::Ceiling($oz/[double]$sizes[-1]); if($count -lt 1){ $count=1 }
    $out.items += @{ name=$k; unit=$u; sku=$sku; packages=@(@{ size_oz=$sizes[-1]; count=$count }) }
  } elseif($floz -ne $null -and $node.packages_fl_oz){
    $sizes=$node.packages_fl_oz | Sort-Object { $_ }; $count=[math]::Ceiling($floz/[double]$sizes[-1]); if($count -lt 1){ $count=1 }
    $out.items += @{ name=$k; unit=$u; sku=$sku; packages=@(@{ size_fl_oz=$sizes[-1]; count=$count }) }
  } else {
    $out.items += @{ name=$k; unit=$u; sku=$sku; warning="No compatible package sizes" }
  }
}

$dirOut=Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Quantized shopping -> $OutFile"
