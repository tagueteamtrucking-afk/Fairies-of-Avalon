param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$Boards = 8,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
function Get-LatestWorld([string]$Dir){
  $seeds = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($seeds){ $bn = [System.IO.Path]::GetFileNameWithoutExtension($seeds[0].Name); return $bn.Substring(5) }
  $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $world = "world-" + $ts
  $seed = @{ world = $world; title = "World $ts"; notes = "Auto-seed by Tracy." } | ConvertTo-Json -Depth 20
  Set-Content -LiteralPath (Join-Path $Dir ("seed-" + $world + ".json")) -Value $seed -Encoding UTF8
  return $world
}
$worldId = if([string]::IsNullOrWhiteSpace($World)) { Get-LatestWorld $worldsDir } else { $World }

# Load assets for flavor (best-effort)
$choicesPath = Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json'
$CH = if(Test-Path $choicesPath){ try { Get-Content -LiteralPath $choicesPath -Raw | ConvertFrom-Json } catch { @{} } } else { @{} }
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }

$atlasPath = Join-Path $worldsDir ("atlas-" + $worldId + ".json")
$atlas = $null; if(Test-Path $atlasPath){ try { $atlas = Get-Content -LiteralPath $atlasPath -Raw | ConvertFrom-Json } catch {} }
$regions = @(); if($atlas -and $atlas.regions){ foreach($r in $atlas.regions){ $regions += $r.name } }
if($regions.Count -eq 0){ $regions = @("Northreach","Sunforge","Evershade","Frostmarsh") }

$themes = @("futuristic fantasy","magitech","neo‑baroque","crystalpunk","solarpunk","dieselpunk ruins","astral gothic")

$boards = @()
for($i=0;$i -lt [Math]::Max(1,$Boards);$i++){
  $boards += [ordered]@{
    id = "art-" + ([guid]::NewGuid().ToString("N").Substring(0,8))
    type = Pick @("key art","location matte","character sheet","prop pack","ui icon set","map tile","poster","cover")
    theme = Pick $themes
    region = Pick $regions
    brief = "Compose a "+ (Pick @("dynamic","moody","heroic","intimate","architectural","cinematic","documentary")) +
            " scene in the theme '"+ (Pick $themes) +"' for region '"+ (Pick $regions) +"'."
    deliverables = @("1x 4k hero","2x alternates","turnaround (if character)","color keys","value thumbnails")
    notes = @("respect silhouettes","readable at thumbnail","save layered PSD/ORA","export PNG & WebP")
  }
}

$outDir = Join-Path $worldsDir 'artboards'
if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$outPath = Join-Path $outDir ("artboard-" + $worldId + ".json")
$boards | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
