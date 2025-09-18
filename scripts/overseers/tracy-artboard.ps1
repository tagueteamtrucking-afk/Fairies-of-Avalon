param([Parameter(Mandatory=$true)][string]$RepoRoot,[string]$World,[int]$Boards=8)
$ErrorActionPreference='Stop'
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
function Latest([string]$d){ $s=Get-ChildItem -LiteralPath $d -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select -First 1; if($s){ return ($s.BaseName.Substring(5)) } $ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $w="world-"+$ts; $seed=@{world=$w;title="World $ts";notes="Auto-seed by Tracy"}|ConvertTo-Json -Depth 20; Set-Content -LiteralPath (Join-Path $d ("seed-"+$w+".json")) -Value $seed -Encoding UTF8; return $w }
$wid = if([string]::IsNullOrWhiteSpace($World)){ Latest $worldsDir } else { $World }
$CH=Get-Content (Join-Path $RepoRoot 'pages/apps/alexandria/knowledge/choices.json') -Raw | ConvertFrom-Json
function Pick([array]$arr){ if(!$arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
$themes=@("futuristic fantasy","magitech","neo‑baroque","crystalpunk","solarpunk","dieselpunk ruins","astral gothic")
$regions=@("Northreach","Sunforge","Evershade","Frostmarsh","Skydock","Umber Vale")
$boards=@()
for($i=0;$i -lt [Math]::Max(1,$Boards);$i++){
  $boards += [ordered]@{
    id = "art-" + ([guid]::NewGuid().ToString("N").Substring(0,8))
    type = Pick @("key art","location matte","character sheet","prop pack","ui icon set","map tile","poster","cover")
    theme = Pick $themes
    region = Pick $regions
    brief = "Compose a " + (Pick @("dynamic","moody","heroic","intimate","architectural","cinematic","documentary")) + " scene in '" + (Pick $themes) + "' for region '" + (Pick $regions) + "'."
    deliverables = @("4k hero","2x alternates","turnaround (if character)","color keys","value thumbnails")
    notes = @("clear silhouettes","thumb readability","export PNG & WebP")
  }
}
$outDir=Join-Path $worldsDir 'artboards'; if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir|Out-Null }
$outPath=Join-Path $outDir ("artboard-"+$wid+".json"); $boards|ConvertTo-Json -Depth 100|Set-Content $outPath -Encoding UTF8; Write-Host "Wrote $outPath"
