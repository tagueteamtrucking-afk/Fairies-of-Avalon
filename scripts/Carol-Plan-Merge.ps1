param(
  [string]$Good7 = "pages/apps/carol/plans/twoperson-2wk-20251014T234049Z.json",
  [string]$Unique14 = "pages/apps/carol/plans/twoperson-2wk-unique-20251015T022300Z.json",
  [string]$OutFile = "pages/apps/carol/plans/twoperson-2wk-merged.json",
  [switch]$SwapHardFoodsToButters
)
$ErrorActionPreference="Stop"
if(!(Test-Path $Good7)){ throw "Good7 file not found at $Good7" }
if(!(Test-Path $Unique14)){ throw "Unique14 file not found at $Unique14" }

$g = Get-Content $Good7 -Raw | ConvertFrom-Json
$u = Get-Content $Unique14 -Raw | ConvertFrom-Json

# Build dictionary of days by index for both
$gmap = @{}
$g.days | ForEach-Object { $gmap[[int]$_.index] = $_ }
$umap = @{}
$u.days | ForEach-Object { $umap[[int]$_.index] = $_ }

# Start with Unique14 days as base
$days = @()
for($i=1; $i -le 14; $i++){
  if($i -le 7 -and $gmap.ContainsKey($i)){ $days += $gmap[$i] } else { $days += $umap[$i] }
}

# Optional: convert hard nuts to nut butters for safety
if($SwapHardFoodsToButters.IsPresent){
  foreach($d in $days){
    foreach($ev in $d.events){
      foreach($it in $ev.items){
        $ing = ($it.ingredient+"").ToLower()
        if($ing -match "almonds"){
          $it.ingredient = "almond butter"
          # map 1 oz nuts -> 2 tbsp nut butter
          if($it.unit -eq "oz"){ $it.quantity = 2; $it.unit = "tbsp" }
        }
        elseif($ing -match "walnuts"){
          $it.ingredient = "walnut butter"
          if($it.unit -eq "oz"){ $it.quantity = 2; $it.unit = "tbsp" }
        }
      }
    }
  }
}

# Compose merged plan
$merged = [ordered]@{
  updated = (Get-Date).ToString("o")
  region  = $u.region
  pattern = $u.pattern
  weeks   = 2
  persons = $u.persons
  days    = $days
}

$dir = Split-Path -Parent $OutFile
if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$merged | ConvertTo-Json -Depth 8 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "Wrote merged plan -> $OutFile"
