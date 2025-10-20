param(
  [string]$ShoppingFile = "pages/apps/carol/plans/shopping-extracted.json",
  [string]$PackageMap   = "pages/apps/carol/packages/us.json",
  [string]$OutFile      = "pages/apps/carol/plans/shopping-quantized.json"
)
$ErrorActionPreference="Stop"
if(!(Test-Path $ShoppingFile)){ throw "Shopping-extracted not found: $ShoppingFile. Run Extract first." }
if(!(Test-Path $PackageMap)){ throw "Package map not found: $PackageMap" }
$shop = Get-Content $ShoppingFile -Raw | ConvertFrom-Json
$map  = Get-Content $PackageMap -Raw | ConvertFrom-Json

$packages = @()
$unmapped = @()

foreach($row in $shop.items){
  $key = ($row.ingredient+"").Trim().ToLower()
  if($map.PSObject.Properties.Name -contains $key){
    $pm = $map.$key
    $targetUnit = ($pm.unit+"" ).ToLower()
    if((($row.unit+"").ToLower()) -ne $targetUnit){
      # Units mismatch -> send to unmapped for manual review
      $unmapped += [PSCustomObject]@{ ingredient=$row.ingredient; have=$row.total; have_unit=$row.unit; expected_unit=$targetUnit; note="unit mismatch" }
      continue
    }
    $pkgSize = [double]$pm.package_size
    if($pkgSize -le 0){ $unmapped += [PSCustomObject]@{ ingredient=$row.ingredient; have=$row.total; have_unit=$row.unit; expected_unit=$targetUnit; note="bad package_size" }; continue }
    $need = [math]::Ceiling([double]$row.total / $pkgSize)
    $packages += [PSCustomObject]@{
      ingredient = $row.ingredient
      buy_packages = [int]$need
      package_label = ($pm.package_label+"" )
      approx_unit_total = [math]::Round($need * $pkgSize,3)
      unit = $targetUnit
    }
  } else {
    $unmapped += [PSCustomObject]@{ ingredient=$row.ingredient; have=$row.total; have_unit=$row.unit; expected_unit=$null; note="no map" }
  }
}

$out = [PSCustomObject]@{
  updated = (Get-Date).ToString("o")
  from = $ShoppingFile
  packages = $packages | Sort-Object ingredient
  review   = $unmapped | Sort-Object ingredient
}
$dir = Split-Path -Parent $OutFile
if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "Quantized -> $OutFile (packages: $($packages.Count), review: $($unmapped.Count))"
