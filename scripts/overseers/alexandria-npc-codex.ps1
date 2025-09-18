param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$Count = 12
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ throw "No worlds dir: $worldsDir" }

function EnsureWorld([string]$Dir,[string]$W){
  if([string]::IsNullOrWhiteSpace($W)){
    $latest = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if(!$latest){ throw "No seeds directory found: $Dir" }
    return ($latest.BaseName.Substring(5))
  }
  return $W
}
$World = EnsureWorld $worldsDir $World

$choicesPath = Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json'
$CH = Get-Content -LiteralPath $choicesPath -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
function Make-Name(){ $a=$CH.name_syllables_a[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_a.Count)]; $b=$CH.name_syllables_b[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_b.Count)]; $c=$CH.name_syllables_a[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_a.Count)]; $n=$a+$b+$c; return ($n.Substring(0,1).ToUpper()+$n.Substring(1)) }

$npcs=@()
for($i=1;$i -le [Math]::Max(1,$Count);$i++){
  $npcs += [ordered]@{
    id = "npc-" + $i
    name = Make-Name()
    profession = Pick $CH.professions
    trait = Pick $CH.traits
    motive = Pick $CH.motives
    secret = Pick $CH.secrets
    alignment = Pick $CH.alignments
  }
}
$out = [ordered]@{ world=$World; npcs=$npcs }
$outPath = Join-Path $worldsDir ("npcs-" + $World + ".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
