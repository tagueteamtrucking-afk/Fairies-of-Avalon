[CmdletBinding()]
param([string]$RepoRoot=".", [string]$Goal="strength")
$ErrorActionPreference='Stop'
$split = @(
  @{ day='Mon'; exercises=@(@{name='Squat'; scheme='5x5'}, @{name='Accessory'; scheme='3x10'}) },
  @{ day='Tue'; exercises=@(@{name='Bench'; scheme='5x5'}, @{name='Pull'; scheme='3x10'}) },
  @{ day='Thu'; exercises=@(@{name='Deadlift'; scheme='3x5'}, @{name='Core'; scheme='3x12'}) },
  @{ day='Sat'; exercises=@(@{name='Press'; scheme='5x5'}, @{name='Row'; scheme='3x8'}) }
)
$plan = @{ goal=$Goal; week=$split; generated=(Get-Date).ToUniversalTime().ToString("s") + 'Z' }
$outDir = Join-Path $RepoRoot "pages/apps/jem"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
($plan | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "workout.json") -Encoding utf8NoBOM
Write-Host "Workout plan written."
exit 0
