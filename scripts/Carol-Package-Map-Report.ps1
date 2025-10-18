param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$PackageMap="pages/apps/carol/packages/us.json",
  [string]$OutFile="pages/apps/carol/plans/packages-missing.json",
  [string]$ShoppingFile=""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $root $PlansDir
$mapAbs = Join-Path $root $PackageMap
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $mapAbs)){ Write-Error "Package map not found at $mapAbs"; exit 1 }
$map = Get-Content -Raw -Path $mapAbs | ConvertFrom-Json

function Load-Shopping(){
  if(-not [string]::IsNullOrWhiteSpace($ShoppingFile)){
    $sf = Join-Path $root $ShoppingFile
    if(Test-Path $sf){
      try{ return (Get-Content -Raw -Path $sf | ConvertFrom-Json).items } catch {}
    }
  }

  $files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending
  foreach($f in $files){
    try{
      $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
      if($j.shopping){ return $j.shopping }
      elseif($j.menu -and $j.menu.shopping){ return $j.menu.shopping }
      elseif($j.items){ return $j.items }
    } catch { continue }
  }

  # fallback: call extractor
  $extract = Join-Path $root "scripts/Carol-Extract-Shopping.ps1"
  if(Test-Path $extract){
    pwsh -File $extract -PlansDir $PlansDir -OutFile "pages/apps/carol/plans/shopping-extracted.json"
    $sx = Join-Path $root "pages/apps/carol/plans/shopping-extracted.json"
    if(Test-Path $sx){ try{ return (Get-Content -Raw -Path $sx | ConvertFrom-Json).items } catch {} }
  }
  return $null
}

$shopping = Load-Shopping
if($null -eq $shopping -or $shopping.Count -eq 0){
  Write-Error "No shopping items found even after extraction. Ensure at least one plan JSON exists with ingredients."
  exit 1
}

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
