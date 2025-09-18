param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ throw "No worlds dir: $worldsDir" }

function Read-Json($p){ if(!(Test-Path $p)){ return $null } try { Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } catch { $null } }
$seed = if([string]::IsNullOrWhiteSpace($World)){ $null } else { Read-Json (Join-Path $worldsDir ("seed-" + $World + ".json")) }
if(!$seed){
  $latest = Get-ChildItem -LiteralPath $worldsDir -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(!$latest){ throw "No seed files found under /pages/apps/alexandria/worlds. Generate one first." }
  $World = ($latest.BaseName.Substring(5))
  $seed = Read-Json $latest.FullName
}

$choicesPath = Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json'
$CH = Get-Content -LiteralPath $choicesPath -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }

$bible = [ordered]@{
  world = $World
  culture = @{
    languages = @("Common","Old Tongue","Trade Cant")
    customs   = @("guest rights","ring‑binding oaths","festival of bridges")
  }
  government = Pick $CH.government_types
  economy    = Pick $CH.economy_types
  magic      = Pick $CH.magic_models
  religion   = @{
    pantheons = ($CH.myth_pantheons | Select-Object -First 2)
    deities   = ($CH.myth_deities | Select-Object -First 6)
  }
  factions   = ($CH.factions | Select-Object -First 4)
}
$outPath = Join-Path $worldsDir ("bible-" + $World + ".json")
$bible | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
