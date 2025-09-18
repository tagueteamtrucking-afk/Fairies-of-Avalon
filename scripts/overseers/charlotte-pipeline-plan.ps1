param([Parameter(Mandatory=$true)][string]$RepoRoot,[string]$World,[string]$TargetLangs="es")
$ErrorActionPreference='Stop'
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir|Out-Null }
function Latest([string]$d){ $s=Get-ChildItem -LiteralPath $d -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select -First 1; if($s){ return ($s.BaseName.Substring(5)) } $ts=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $w="world-"+$ts; $seed=@{world=$w;title="World $ts";notes="Auto-seed by Charlotte"}|ConvertTo-Json -Depth 20; Set-Content -LiteralPath (Join-Path $d ("seed-"+$w+".json")) -Value $seed -Encoding UTF8; return $w }
$wid = if([string]::IsNullOrWhiteSpace($World)){ Latest $worldsDir } else { $World }

$scenesPath = Join-Path $worldsDir ("exports/Scenes-" + $wid + ".md")
if(!(Test-Path $scenesPath)){
  $stub=@("# World Scenes — "+$wid,"","## Opening","A mysterious visitor arrives at the harbor.","")
  $dir=Split-Path -Parent $scenesPath; if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir|Out-Null }
  Set-Content -LiteralPath $scenesPath -Value ($stub -join "`n") -Encoding UTF8
}

$md = Get-Content -LiteralPath $scenesPath -Raw
$parts = ($md -split "(?m)^## ")

$ssmlDir = Join-Path $worldsDir "pipelines/tts"; New-Item -ItemType Directory -Force -Path $ssmlDir|Out-Null
$idx=0; $ssmlFiles=@()
foreach($p in $parts){
  $section=$p.Trim(); if([string]::IsNullOrWhiteSpace($section)){ continue }
  $idx++; $title,$body = if($section.Contains("`n")){ $section.Split("`n",2) } else { @("Scene "+$idx,$section) }
  $ssml="<speak><p><s>"+[System.Web.HttpUtility]::HtmlEncode($title)+"</s></p><p>"+[System.Web.HttpUtility]::HtmlEncode($body)+"</p></speak>"
  $path=Join-Path $ssmlDir ("scene-"+$idx+".ssml")
  Set-Content -LiteralPath $path -Value $ssml -Encoding UTF8
  $ssmlFiles += ("pages/apps/alexandria/worlds/pipelines/tts/scene-"+$idx+".ssml")
}

$langs=@($TargetLangs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$trDir = Join-Path $worldsDir "pipelines/translations"; New-Item -ItemType Directory -Force -Path $trDir|Out-Null
$translations=@()
foreach($lang in $langs){
  $out = Join-Path $trDir ("Scenes-" + $wid + "." + $lang + ".md")
  Set-Content -LiteralPath $out -Value $md -Encoding UTF8
  $translations += [ordered]@{ lang=$lang; file=("pages/apps/alexandria/worlds/pipelines/translations/Scenes-"+$wid+"."+$lang+".md") }
}

$pipeline=[ordered]@{ world=$wid; tts=@{engine="browser-ssml"; voice="default"; ssml_files=$ssmlFiles}; translations=$translations; package=@{outputs=@($ssmlFiles + ($translations|ForEach-Object{$_.file}))} }
$pipeDir=Join-Path $worldsDir "pipelines"; if(!(Test-Path $pipeDir)){ New-Item -ItemType Directory -Force -Path $pipeDir|Out-Null }
$pipePath=Join-Path $pipeDir ("pipeline-" + $wid + ".json")
$pipeline|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $pipePath -Encoding UTF8
Write-Host "Wrote $pipePath"
