param([Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$World,[int]$PerTown=3,[switch]$ForceFallback)
$ErrorActionPreference='Stop'
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
$ch=Get-Content (Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json') -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
function Name(){ $a=Pick $ch.name_syllables_a; $b=Pick $ch.name_syllables_b; $c=Pick $ch.name_syllables_a; $n=$a+$b+$c; return ($n.Substring(0,1).ToUpper()+$n.Substring(1)) }
$atlasPath=Join-Path $worldsDir ("atlas-"+$World+".json"); $atlas=$null; if(Test-Path $atlasPath){ try{ $atlas=Get-Content $atlasPath -Raw | ConvertFrom-Json }catch{} }
$sett=@(); if($atlas -and $atlas.regions){ foreach($r in $atlas.regions){ if($r.settlements){ foreach($s in $r.settlements){ $sett += $s.name } } } }
if($sett.Count -eq 0){ for($i=0;$i -lt 3;$i++){ $sett += ("Town "+(Name())) } }
$fig=@(); foreach($t in $sett){ $list=@(); for($i=0;$i -lt [Math]::Max(1,$PerTown);$i++){ $list += [ordered]@{name=Name();role=Pick $ch.professions;trait=Pick $ch.traits;motive=Pick $ch.motives;secret=Pick $ch.secrets;alignment=Pick $ch.alignments;town=$t} }; $fig += [ordered]@{settlement=$t;figures=$list} }
$outDir=Join-Path $worldsDir 'codex'; if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir|Out-Null }
$outPath=Join-Path $outDir ("figures-"+$World+".json"); $fig|ConvertTo-Json -Depth 100|Set-Content $outPath -Encoding UTF8; Write-Host "Wrote $outPath"
