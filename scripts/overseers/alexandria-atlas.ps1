param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$Regions = 5
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

$regionsArr=@()
for($i=1;$i -le [Math]::Max(1,$Regions);$i++){
  $sett=@()
  for($j=1;$j -le 3;$j++){
    $tav = (Pick $CH.tavern_adjectives) + " " + (Pick $CH.tavern_nouns)
    $inn = (Pick $CH.tavern_adjectives) + " " + (Pick $CH.tavern_nouns)
    $sett += [ordered]@{
      name = (Make-Name())
      size = (Pick @("hamlet","village","town","city"))
      tavern = @{ name=$tav; traits=@( (Pick $CH.inn_traits), (Pick $CH.inn_traits) ) }
      inn    = @{ name=$inn;  traits=@( (Pick $CH.inn_traits), (Pick $CH.inn_traits) ) }
      notes  = "Known for " + (Pick $CH.regions_templates)
    }
  }
  $regionsArr += [ordered]@{
    name = (Make-Name())
    biome = (Pick $CH.regions_templates)
    settlements = $sett
  }
}
$out = [ordered]@{ world=$World; regions=$regionsArr }
$outPath = Join-Path $worldsDir ("atlas-" + $World + ".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
