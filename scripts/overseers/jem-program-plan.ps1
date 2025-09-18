param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [object]$Weeks = 8,
  [object]$DaysPerWeek = 4,
  [ValidateSet("recomp","hypertrophy","strength","fatloss")][string]$Goal = "recomp",
  [ValidateSet("minimal","gym")][string]$Equipment = "minimal"
)
$ErrorActionPreference='Stop'

function As-Int([object]$x,[int]$default){
  if ($null -eq $x) { return $default }
  if ($x -is [int]) { return [int]$x }
  if ($x -is [long]) { return [int]$x }
  if ($x -is [double]) { return [int][Math]::Round($x) }
  if ($x -is [string]) { $s=$x.Trim(); if ($s -eq "") { return $default }; return [int]$s }
  if ($x -is [object[]]) { foreach($e in $x){ if($null -ne $e -and "$e".Trim() -ne ""){ return [int]("$e") } } return $default }
  return [int]("$x")
}

[int]$WeeksI = As-Int $Weeks 8
[int]$DPWI   = As-Int $DaysPerWeek 4

$root = Join-Path $RepoRoot 'pages/apps/jem/programs'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
$weeks=@()
for($w=1;$w -le [Math]::Max(1,$WeeksI);$w++){ $days=@(); for($d=1;$d -le [Math]::Max(1,$DPWI);$d++){ $days += @{ day=$d; focus="full" } } $weeks += @{ week=$w; days=$days } }
$out = [ordered]@{ created=(Get-Date).ToUniversalTime().ToString('o'); goal=$Goal; equipment=$Equipment; weeks=$weeks }
$ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("program-"+$Goal+"-"+$Equipment+"-"+$ts+".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
