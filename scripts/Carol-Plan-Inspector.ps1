param([string]$PlansDir="pages/apps/carol/plans")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $here $PlansDir
if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
$shoppingExtracted = Join-Path $plansAbs "shopping-extracted.json"
if(Test-Path $shoppingExtracted){
  $doc = Get-Content -Raw -Path $shoppingExtracted | ConvertFrom-Json
  $arr = if($doc.items){ $doc.items } else { $doc.shopping }
  if($arr){ Write-Host "shopping-extracted.json items: $($arr.Count)"; return }
}
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Where-Object {
  $_.Name -notmatch "^shopping-(extracted|quantized)\.json$" -and $_.Name -notmatch "^packages-missing\.json$"
}
$found=0
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
    if($j.shopping){ Write-Host "$($f.Name): shopping[] = $($j.shopping.Count)"; $found++ }
    elseif($j.menu -and $j.menu.shopping){ Write-Host "$($f.Name): menu.shopping[] = $($j.menu.shopping.Count)"; $found++ }
    elseif($j.menu -and $j.menu.days){ Write-Host "$($f.Name): menu.days[] present (run Extract v2)" }
    else{ Write-Host "$($f.Name): no shopping array" }
  } catch {
    Write-Host "$($f.Name): JSON parse error"
  }
}
if($found -eq 0){ Write-Host "No plan JSONs with shopping array found. Run Extract v2 to build shopping-extracted.json." }
