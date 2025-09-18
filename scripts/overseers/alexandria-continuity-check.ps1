param([Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$World)
$ErrorActionPreference='Stop'
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
function RJ($p){ if(!(Test-Path $p)){ return $null } try{ Get-Content $p -Raw | ConvertFrom-Json }catch{ $null } }
$atlas=RJ (Join-Path $worldsDir ("atlas-"+$World+".json"))
$time=RJ (Join-Path $worldsDir ("timeline-"+$World+".json"))
$figs=RJ (Join-Path $worldsDir ("codex/figures-"+$World+".json"))
$regions=@{};$towns=@{}
if($atlas -and $atlas.regions){ foreach($r in $atlas.regions){ $regions[$r.name]=$true; if($r.settlements){ foreach($s in $r.settlements){ $towns[$s.name]=$true } } } }
$issues=@()
if($time -and $time.events){ foreach($e in $time.events){ $loc=$e.location; if($loc -and -not ($regions.ContainsKey($loc) -or $towns.ContainsKey($loc))){ $issues += @{type="missing_location";event=$e.title;location=$loc} } } }
if($figs){ foreach($entry in $figs){ $sett=$entry.settlement; if($sett -and -not $towns.ContainsKey($sett)){ $issues += @{type="figure_unknown_settlement";settlement=$sett} } } }
$outDir=Join-Path $worldsDir 'reports'; if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir|Out-Null }
$out=[ordered]@{world=$World;timestamp=(Get-Date).ToUniversalTime().ToString('o');issues=$issues}
$outPath=Join-Path $outDir ("continuity-"+$World+".json"); $out|ConvertTo-Json -Depth 100|Set-Content $outPath -Encoding UTF8; Write-Host "Wrote $outPath"
