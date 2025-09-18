param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Days = 7,
  [int]$KcalTarget = 2200,
  [ValidateSet("balanced","mediterranean","keto","vegetarian")][string]$DietStyle = "balanced"
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'pages/apps/carol/plans'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
$out = [ordered]@{ created=(Get-Date).ToUniversalTime().ToString('o'); style=$DietStyle; target_kcal=$KcalTarget; days=@() }
for($d=1;$d -le [Math]::Max(1,$Days);$d++){ $out.days += @{ day=$d; meals=@("breakfast","lunch","dinner","snack") } }
$ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("mealplan-"+$DietStyle+"-"+$ts+".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
