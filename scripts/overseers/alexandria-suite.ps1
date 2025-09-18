param([Parameter(Mandatory=$true)][string]$RepoRoot,[string]$World,[int]$PerTown=3,[switch]$ForceFallback)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }
function Latest([string]$d){ $s=Get-ChildItem -LiteralPath $d -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select -First 1; if($s){ return ($s.BaseName.Substring(5)) } $ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $w="world-"+$ts; $seed=@{world=$w;title="World $ts";notes="Auto-seed by helpers"}|ConvertTo-Json -Depth 20; Set-Content -LiteralPath (Join-Path $d ("seed-"+$w+".json")) -Value $seed -Encoding UTF8; return $w }
$wid = if([string]::IsNullOrWhiteSpace($World)){ Latest $worldsDir } else { $World }
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-notable-figures.ps1') -RepoRoot $RepoRoot -World $wid -PerTown $PerTown @PSBoundParameters
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-continuity-check.ps1') -RepoRoot $RepoRoot -World $wid
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-author-handoff.ps1') -RepoRoot $RepoRoot -World $wid
& (Join-Path $RepoRoot 'scripts/overseers/alexandria-export-bundle.ps1') -RepoRoot $RepoRoot -World $wid
