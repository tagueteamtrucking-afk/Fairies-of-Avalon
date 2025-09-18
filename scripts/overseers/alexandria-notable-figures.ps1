param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$World,
  [int]$PerTown = 3,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
$choicesPath = Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json'
if(!(Test-Path $choicesPath)){ throw "choices.json not found: $choicesPath" }
$CH = Get-Content -LiteralPath $choicesPath -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
function Make-Name(){ $a=Pick $CH.name_syllables_a; $b=Pick $CH.name_syllables_b; $c=Pick $CH.name_syllables_a; $n=$a+$b+$c; return ($n.Substring(0,1).ToUpper()+$n.Substring(1)) }
$atlasPath = Join-Path $worldsDir ("atlas-" + $World + ".json"); $atlas = $null
if(Test-Path $atlasPath){ try { $atlas = Get-Content -LiteralPath $atlasPath -Raw | ConvertFrom-Json } catch {} }
$settlements = @()
if($atlas -and $atlas.regions){ foreach($r in $atlas.regions){ if($r.settlements){ foreach($s in $r.settlements){ $settlements += $s.name } } } }
if($settlements.Count -eq 0){ for($i=0;$i -lt 3;$i++){ $settlements += ("Town " + (Make-Name())) } }
$figures = @()
foreach($town in $settlements){
  $list=@(); for($i=0;$i -lt [Math]::Max(1,$PerTown);$i++){
    $list += [ordered]@{ name=Make-Name(); role=Pick $CH.professions; trait=Pick $CH.traits; motive=Pick $CH.motives; secret=Pick $CH.secrets; alignment=Pick $CH.alignments; town=$town }
  }
  $figures += [ordered]@{ settlement=$town; figures=$list }
}
$outDir = Join-Path $worldsDir 'codex'; if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$outPath = Join-Path $outDir ("figures-" + $World + ".json")
$figures | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
