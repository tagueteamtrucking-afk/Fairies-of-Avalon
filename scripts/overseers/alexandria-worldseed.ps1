param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$Title,
  [string]$Prompt,
  [int]$Depth = 40,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
if($Depth -gt 100){ $Depth = 100 }

$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

function Slug([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return $null }
  $x = $s.ToLowerInvariant()
  $x = ($x -replace "[^a-z0-9\- ]","").Trim()
  $x = ($x -replace "\s+","-")
  return $x
}
function NowIso(){ (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }

# Load choices
$choicesPath = Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json'
$CH = Get-Content -LiteralPath $choicesPath -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
function Make-Name(){ $a=$CH.name_syllables_a[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_a.Count)]; $b=$CH.name_syllables_b[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_b.Count)]; $c=$CH.name_syllables_a[(Get-Random -Minimum 0 -Maximum $CH.name_syllables_a.Count)]; $n=$a+$b+$c; return ($n.Substring(0,1).ToUpper()+$n.Substring(1)) }

if([string]::IsNullOrWhiteSpace($Title)){ $Title = "Avalon " + (NowIso()) }
$slug = Slug $Title
if([string]::IsNullOrWhiteSpace($slug)){ $slug = "world-" + (NowIso()) }

$seed = [ordered]@{
  world = $slug
  title = $Title
  created = (Get-Date).ToUniversalTime().ToString('o')
  prompt = $Prompt
  premise = "An isekai‑tinged futuristic fantasy where portals weave between regions."
  themes = @("isekai","dungeon‑crawl","political intrigue","frontier exploration")
  pantheons = ($CH.myth_pantheons | Select-Object -First 3)
  factions = ($CH.factions | Select-Object -First 4)
}

$seedPath = Join-Path $worldsDir ("seed-" + $slug + ".json")
$seed | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $seedPath -Encoding UTF8
Write-Host "Wrote $seedPath"
