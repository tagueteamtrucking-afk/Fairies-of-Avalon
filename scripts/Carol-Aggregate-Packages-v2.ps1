param([string]$PlansDir="pages/apps/carol/plans",[string]$PackageMap="pages/apps/carol/packages/us.json",[string]$OutFile="pages/apps/carol/plans/shopping-quantized.json",[int]$Persons=2)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $here $PlansDir
$pkgAbs   = Join-Path $here $PackageMap
$outAbs   = Join-Path $here $OutFile
function Load-Json($p){ try { Get-Content -Raw -Path $p | ConvertFrom-Json -ErrorAction Stop } catch { $null } }
function Norm($s){ if($null -eq $s){ return $null }; return ($s.ToString().Trim().ToLower()) }
function NormUnit($u){ $u = Norm($u); switch ($u){ "tablespoon" {"tbsp"} "tbs" {"tbsp"} "tbsp" {"tbsp"} "teaspoon" {"tsp"} "tsp" {"tsp"} "cup" {"cups"} "cups" {"cups"} "ct" {"ct"} "count" {"ct"} "oz" {"oz"} "fl oz" {"fl_oz"} "floz" {"fl_oz"} default { $u } } }
if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
if(-not (Test-Path $pkgAbs)){ Write-Error "PackageMap not found: $pkgAbs"; exit 1 }
$pkg = Load-Json $pkgAbs; if($null -eq $pkg){ Write-Error "Could not parse PackageMap at $pkgAbs"; exit 1 }
$ingredientMap = @{}; if($pkg.ingredient_map){ foreach($p in $pkg.ingredient_map.PSObject.Properties){ $ingredientMap[(Norm $p.Name)] = (Norm $p.Value) } }
$packageSizes = $pkg.package_sizes
$shoppingExtracted = Join-Path $plansAbs "shopping-extracted.json"
$items = @()
if(Test-Path $shoppingExtracted){ $doc = Load-Json $shoppingExtracted; if($doc){ if($doc.items){ $items = @($doc.items) } elseif($doc.shopping){ $items = @($doc.shopping) } } }
if($items.Count -eq 0){
  $candidates = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Where-Object { $_.Name -notmatch "^shopping-(extracted|quantized)\.json$" -and $_.Name -notmatch "^packages-missing\.json$" }
  foreach($f in $candidates){
    $j = Load-Json $f.FullName; if($null -eq $j){ continue }
    if($j.shopping){ $items += @($j.shopping); continue }
    if($j.menu -and $j.menu.shopping){ $items += @($j.menu.shopping); continue }
    if($j.menu -and $j.menu.days){ foreach($d in $j.menu.days){ if($d.shopping){ $items += @($d.shopping) } } }
  }
}
if($items.Count -eq 0){ Write-Error "No shopping items found. Run Carol-Extract-Shopping-v3.ps1 first."; exit 1 }
$agg = @{}; foreach($x in $items){ $n = $x.name; if(-not $n){ $n = $x.item }; $u = $x.unit; $q = $x.qty; if($null -eq $n -or $null -eq $q){ continue }; $n = Norm $n; $u = NormUnit $u; $canon = if($ingredientMap.ContainsKey($n)) { $ingredientMap[$n] } else { $n }; $key = "$canon|$u"; if(-not $agg.ContainsKey($key)){ $agg[$key] = [double]$q } else { $agg[$key] += [double]$q } }
foreach($k in @($agg.Keys)){ $agg[$k] = $agg[$k] * [double]$Persons }
function Choose-Package($canon, $unit, $need){
  $sizesProp = $packageSizes.PSObject.Properties[$canon]; if($null -eq $sizesProp){ return $null }
  $sizes = $sizesProp.Value; $best = $null
  foreach($opt in $sizes){
    $cap = $null
    switch($unit){ "tbsp" { $cap = $opt.tbsp_per_package } "cups" { $cap = $opt.cups_per_package } "ct" { $cap = $opt.count } "oz" { $cap = $opt.net_oz } "fl_oz" { $cap = $opt.fl_oz } default { $cap = $null } }
    if($null -eq $cap -or $cap -le 0){ continue }
    $packs = [math]::Ceiling($need / [double]$cap); $left  = ($packs * [double]$cap) - [double]$need
    $cand = @{ package=$opt.package; capacity_per_package=$cap; packages=[int]$packs; leftover=[double]$left }
    if($null -eq $best -or $cand.leftover -lt $best.leftover -or ($cand.leftover -eq $best.leftover -and $cand.packages -lt $best.packages)){ $best = $cand }
  }
  return $best
}
$out = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; persons=$Persons; package_map="/"+($pkgAbs.Replace($here,"").TrimStart('\','/').Replace('\','/')); items=@(); unmapped=@() }
foreach($k in $agg.Keys){
  $parts = $k.Split("|",2); $canon=$parts[0]; $unit=$parts[1]; $need=[double]$agg[$k]
  $choice = Choose-Package $canon $unit $need
  if($null -eq $choice){ $out.unmapped += @{ name=$canon; required_qty=[math]::Round($need,2); unit=$unit } }
  else { $out.items += @{ name=$canon; required_qty=[math]::Round($need,2); unit=$unit; package=$choice.package; packages=$choice.packages; capacity_per_package=$choice.capacity_per_package; leftover=[math]::Round($choice.leftover,2) } }
}
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
