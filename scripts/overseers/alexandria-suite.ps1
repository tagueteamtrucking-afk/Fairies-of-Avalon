param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$PerTown = 3,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'

$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

# Choose latest world seed if not provided
function Get-LatestWorld {
  param([string]$Dir)
  $seeds = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($seeds -and $seeds.Count -gt 0){
    $bn = [System.IO.Path]::GetFileNameWithoutExtension($seeds[0].Name)
    if($bn.StartsWith('seed-')){ return $bn.Substring(5) }
  }
  # If no seeds, make a minimal one
  $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  $world = "avalon-" + $ts
  $seed = @{
    world = $world
    title = "Avalon $ts"
    notes = "Auto-seed created by Helpers Suite."
  } | ConvertTo-Json -Depth 20
  $seedPath = Join-Path $Dir ("seed-" + $world + ".json")
  Set-Content -LiteralPath $seedPath -Value $seed -Encoding UTF8
  return $world
}

$worldId = if([string]::IsNullOrWhiteSpace($World)) { Get-LatestWorld $worldsDir } else { $World }

# Run steps
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-notable-figures.ps1') -RepoRoot $RepoRoot -World $worldId -PerTown $PerTown @PSBoundParameters
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-continuity-check.ps1') -RepoRoot $RepoRoot -World $worldId
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-author-handoff.ps1') -RepoRoot $RepoRoot -World $worldId
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-export-bundle.ps1') -RepoRoot $RepoRoot -World $worldId
