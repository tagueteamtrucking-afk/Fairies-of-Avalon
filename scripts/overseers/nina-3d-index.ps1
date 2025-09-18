param([Parameter(Mandatory=$true)][string]$RepoRoot,[int]$MaxCombos=12,[string]$World)
$ErrorActionPreference='Stop'
$wingedAlias = Join-Path $RepoRoot 'asset/winged-models'
$modelsRoot  = Join-Path $RepoRoot 'asset/models'
$wingsRoot   = Join-Path $RepoRoot 'asset/wings'

$models=@()
foreach($dir in @($wingedAlias,$modelsRoot)){
  if(Test-Path $dir){
    $models += Get-ChildItem -LiteralPath $dir -File -Filter *.vrm -ErrorAction SilentlyContinue | ForEach-Object {
      [ordered]@{ file = $_.FullName.Replace($RepoRoot,'').Replace('\','/').TrimStart('/'); name = $_.BaseName; preWinged = ($dir -eq $wingedAlias) }
    }
  }
}

$wings=@()
$wingsManifest = Join-Path $wingsRoot 'manifest.json'
if(Test-Path $wingsManifest){
  try { $wj = Get-Content -LiteralPath $wingsManifest -Raw | ConvertFrom-Json; if($wj){ $wings = $wj } } catch {}
}else{
  $texDir = Join-Path $wingsRoot 'textures'
  if(Test-Path $texDir){
    $pngs = Get-ChildItem -LiteralPath $texDir -File -Filter *.png -ErrorAction SilentlyContinue
    $groups = @{}
    foreach($p in $pngs){ if($p.BaseName -match '(?i)wing(\d+)'){ $n=$Matches[1]; if(!$groups.ContainsKey($n)){ $groups[$n]=@() }; $groups[$n]+=$p.Name } }
    foreach($k in $groups.Keys){ $wings += [ordered]@{ id="wing"+$k; textures=$groups[$k] } }
  }
}

$combos=@()
foreach($m in $models){
  if($m.preWinged){ $combos += [ordered]@{ model=$m.file; wing=$null; combo='pre-winged' } }
  else{
    foreach($w in ($wings | Select-Object -First $MaxCombos)){
      $combos += [ordered]@{ model=$m.file; wing=$w.id; combo="$($m.name)+$($w.id)" }
    }
  }
}

$index = [ordered]@{ generated=(Get-Date).ToUniversalTime().ToString('o'); models=$models; wings=$wings; combos=$combos }
$outIndex = Join-Path $RepoRoot 'pages/apps/overseers/vrm-index.json'
$index | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outIndex -Encoding UTF8
Write-Host "Wrote $outIndex"

if($World){
  $worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
  $sceneDir = Join-Path $worldsDir '3d'; if(!(Test-Path $sceneDir)){ New-Item -ItemType Directory -Force -Path $sceneDir|Out-Null }
  $scene = [ordered]@{ world=$World; selections=@($combos | Select-Object -First ([Math]::Min($MaxCombos,$combos.Count))); camera=@{ position=@(0,1.4,2.5); target=@(0,1.3,0) } }
  $scenePath = Join-Path $sceneDir ("SceneKit-" + $World + ".json")
  $scene | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $scenePath -Encoding UTF8
  Write-Host "Wrote $scenePath"
}
