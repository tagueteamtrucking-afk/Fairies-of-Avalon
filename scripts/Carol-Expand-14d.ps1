param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$OutFile="pages/apps/carol/plans/plan-14d.json"
)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $here $PlansDir
$outAbs = Join-Path $here $OutFile
if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
function Load-Json($p){ try { Get-Content -Raw -Path $p | ConvertFrom-Json -ErrorAction Stop } catch { $null } }
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending | Where-Object {
  $_.Name -notmatch "^shopping-(extracted|quantized)\.json$" -and $_.Name -notmatch "^packages-missing\.json$"
}
if(-not $files){ Write-Error "No plan JSONs in $plansAbs"; exit 1 }
$base = $null
foreach($f in $files){
  $j = Load-Json $f.FullName
  if($null -eq $j){ continue }
  $days = if($j.menu -and $j.menu.days){ $j.menu.days } elseif($j.days){ $j.days } else { $null }
  if($days){ $base = @{ file=$f.FullName; json=$j; days=$days }; break }
}
if($null -eq $base){ Write-Error "Could not find a plan with days[]"; exit 1 }
$days = @($base.days)
if($days.Count -ge 14){ Write-Host "Plan already has $($days.Count) days. Nothing to do."; exit 0 }
if($days.Count -lt 7){ Write-Error "Found only $($days.Count) days (<7). Need 7 to build 14."; exit 1 }

# Duplicate days 1..7 into 8..14 with a 'repeat_of' note
$target = @($days)
for($i=$days.Count; $i -lt 14; $i++){
  $src = $days[$i % 7] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
  $src.note = "Repeat of day " + (($i%7)+1)
  $target += $src
}

# Write back in the same structure
if($base.json.menu -and $base.json.menu.days){
  $base.json.menu.days = $target
} elseif($base.json.days){
  $base.json.days = $target
}

$dir = Split-Path -Parent $outAbs
if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($base.json | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Wrote $OutFile with 14 days."
