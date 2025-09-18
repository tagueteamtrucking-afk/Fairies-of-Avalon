param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [object]$Days = 7,
  [object]$KcalTarget = 2200,
  [ValidateSet("balanced","mediterranean","keto","vegetarian")][string]$DietStyle = "balanced"
)
$ErrorActionPreference='Stop'

function As-Int([object]$x, [int]$default){
  if ($null -eq $x) { return $default }
  if ($x -is [int]) { return [int]$x }
  if ($x -is [long]) { return [int]$x }
  if ($x -is [double]) { return [int][Math]::Round($x) }
  if ($x -is [string]) { $s=$x.Trim(); if ($s -eq "") { return $default }; return [int]$s }
  if ($x -is [object[]]) {
    foreach($e in $x){ if($null -ne $e -and "$e".Trim() -ne ""){ return [int]("$e") } }
    return $default
  }
  return [int]("$x")
}

[int]$DaysI = As-Int $Days 7
[int]$KcalI = As-Int $KcalTarget 2200

$root = Join-Path $RepoRoot 'pages/apps/carol/plans'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
$out = [ordered]@{ created=(Get-Date).ToUniversalTime().ToString('o'); style=$DietStyle; target_kcal=$KcalI; days=@() }
for($d=1;$d -le [Math]::Max(1,$DaysI);$d++){ $out.days += @{ day=$d; meals=@("breakfast","lunch","dinner","snack") } }
$ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("mealplan-"+$DietStyle+"-"+$ts+".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
