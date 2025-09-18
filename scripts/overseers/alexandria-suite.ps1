param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$PerTown = 3,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

function Get-LatestWorld([string]$Dir){
  $seeds = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($seeds){ $bn = [System.IO.Path]::GetFileNameWithoutExtension($seeds[0].Name); return $bn.Substring(5) }
  $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $world = "world-" + $ts
  $seed = @{ world = $world; title = "World $ts"; notes = "Auto-seed by suite." } | ConvertTo-Json -Depth 20
  Set-Content -LiteralPath (Join-Path $Dir ("seed-" + $world + ".json")) -Value $seed -Encoding UTF8
  return $world
}
$worldId = if([string]::IsNullOrWhiteSpace($World)) { Get-LatestWorld $worldsDir } else { $World }

& (Join-Path $RepoRoot 'scripts/overseers/alexandria-notable-figures.ps1') -RepoRoot $RepoRoot -World $worldId -PerTown $PerTown @PSBoundParameters
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-continuity-check.ps1') -RepoRoot $RepoRoot -World $worldId
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-author-handoff.ps1') -RepoRoot $RepoRoot -World $worldId
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-export-bundle.ps1') -RepoRoot $RepoRoot -World $worldId
