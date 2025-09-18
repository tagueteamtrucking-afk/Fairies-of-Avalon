param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Weeks = 8,
  [int]$DaysPerWeek = 4,
  [ValidateSet("recomp","hypertrophy","strength","fatloss")][string]$Goal = "recomp",
  [ValidateSet("minimal","gym")][string]$Equipment = "minimal"
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'pages/apps/jem/programs'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
$weeks=@()
for($w=1;$w -le [Math]::Max(1,$Weeks);$w++){ $days=@(); for($d=1;$d -le [Math]::Max(1,$DaysPerWeek);$d++){ $days += @{ day=$d; focus="full" } } $weeks += @{ week=$w; days=$days } }
$out = [ordered]@{ created=(Get-Date).ToUniversalTime().ToString('o'); goal=$Goal; equipment=$Equipment; weeks=$weeks }
$ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("program-"+$Goal+"-"+$Equipment+"-"+$ts+".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
