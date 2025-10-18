param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$OutFile="pages/apps/carol/plans/shopping-extracted.json"
)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $here $PlansDir
$outAbs = Join-Path $here $OutFile
if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }

function Load-Json($p){ try { Get-Content -Raw -Path $p | ConvertFrom-Json -ErrorAction Stop } catch { $null } }
function Norm([string]$s){ if($null -eq $s){ return $null }; return $s.Trim() }
function CanonUnit([string]$u){
  if($null -eq $u){ return $null }
  $u = $u.ToLower().Trim()
  switch($u){
    "tablespoon" {"tbsp"}
    "tbs" {"tbsp"}
    "tbsp" {"tbsp"}
    "teaspoon" {"tsp"}
    "tsp" {"tsp"}
    "cup" {"cups"}
    "cups" {"cups"}
    "ct" {"ct"}
    "count" {"ct"}
    "oz" {"oz"}
    "ounce" {"oz"}
    "ounces" {"oz"}
    "fl oz" {"fl_oz"}
    "floz" {"fl_oz"}
    "ml" {"ml"}       # will convert to fl_oz later
    "g" {"g"}         # will convert to oz later
    default { $u }
  }
}

# Heuristic: ingredients that are typically counted (ct)
$ctNames = @("eggs","rice cakes","tortillas","romaine","romaine hearts")

function Push-Item([ref]$acc, [double]$qty, [string]$unit, [string]$name){
  if($qty -le 0){ return }
  $unit = CanonUnit $unit
  $name = Norm $name
  if([string]::IsNullOrWhiteSpace($name)){ return }
  # Normalize conversions to match package map expectations
  if($unit -eq "g"){ $qty = [math]::Round(($qty / 28.3495), 2); $unit = "oz" }
  elseif($unit -eq "ml"){ $qty = [math]::Round(($qty / 29.5735), 2); $unit = "fl_oz" }
  elseif($null -eq $unit -or $unit -eq ""){
    # If no unit, guess 'ct' for common countables; else leave null
    foreach($t in $ctNames){ if($name.ToLower().Contains($t)){ $unit="ct"; break } }
    if($null -eq $unit){ $unit="ct" }
  }
  $acc.Value += @{ name=$name; qty=[double]$qty; unit=$unit }
}

function Parse-Freeform([string]$s){
  # Examples: "1 cup oats", "2 tbsp peanut butter", "14 eggs", "12 oz hummus"
  $s = $s.Trim()
  $m = [regex]::Match($s, '^\s*(\d+(?:\.\d+)?)\s*([a-zA-Z ]+)?\s+(.+?)\s*$')
  if($m.Success){
    $qty = [double]$m.Groups[1].Value
    $unit = $m.Groups[2].Value.Trim()
    $name = $m.Groups[3].Value.Trim()
    if($unit -eq ""){ $unit = $null }
    return ,(@{qty=$qty; unit=$unit; name=$name})
  } else {
    return @()
  }
}

function Harvest-Node([ref]$acc, $node){
  if($null -eq $node){ return }
  if($node -is [string]){
    $cands = Parse-Freeform $node
    foreach($c in $cands){ Push-Item ([ref]$acc.Value) $c.qty $c.unit $c.name }
    return
  }
  if($node -is [System.Array]){
    foreach($x in $node){ Harvest-Node ([ref]$acc.Value) $x }
    return
  }
  # object
  if($node.PSObject.Properties['shopping']){
    Harvest-Node ([ref]$acc.Value) $node.shopping
  }
  if($node.PSObject.Properties['ingredients']){
    foreach($ing in $node.ingredients){
      if($ing -is [string]){
        $cands = Parse-Freeform $ing
        foreach($c in $cands){ Push-Item ([ref]$acc.Value) $c.qty $c.unit $c.name }
      } else {
        $qty = $ing.qty; $unit = $ing.unit; $name = $ing.name
        if(-not $name){ $name = $ing.item }
        if($qty -and $name){ Push-Item ([ref]$acc.Value) $qty $unit $name }
      }
    }
  }
  foreach($key in @('meals','entries','items','snacks','breakfast','lunch','dinner','snack1','snack2','snack3')){
    if($node.PSObject.Properties[$key]){ Harvest-Node ([ref]$acc.Value) $node.$key }
  }
}

$items = @()
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Where-Object { $_.Name -notmatch "^shopping-(extracted|quantized)\.json$" -and $_.Name -notmatch "^packages-missing\.json$" }
foreach($f in $files){
  $j = Load-Json $f.FullName
  if($null -eq $j){ continue }
  if($j.shopping){ Harvest-Node ([ref]$items) $j.shopping }
  if($j.menu){ 
    if($j.menu.shopping){ Harvest-Node ([ref]$items) $j.menu.shopping }
    if($j.menu.days){
      foreach($d in $j.menu.days){
        if($d.shopping){ Harvest-Node ([ref]$items) $d.shopping }
        else { Harvest-Node ([ref]$items) $d }
      }
    }
  } elseif($j.days){
    foreach($d in $j.days){
      if($d.shopping){ Harvest-Node ([ref]$items) $d.shopping }
      else { Harvest-Node ([ref]$items) $d }
    }
  }
}

$flat = @()
foreach($x in $items){
  # ensure normalized structure
  $n = $x.name; if(-not $n){ $n = $x.item }
  $u = $x.unit; $q = $x.qty
  if($n -and $q){ $flat += @{ name=$n; qty=[double]$q; unit=$u } }
}

$doc = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$flat }
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Wrote $OutFile with $($flat.Count) items."
