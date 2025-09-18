param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [string]$TargetLangs = "es",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

function Get-LatestWorld([string]$Dir){
  $seeds = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($seeds){ $bn = [System.IO.Path]::GetFileNameWithoutExtension($seeds[0].Name); return $bn.Substring(5) }
  $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'); $world = "world-" + $ts
  $seed = @{ world = $world; title = "World $ts"; notes = "Auto-seed by Charlotte." } | ConvertTo-Json -Depth 20
  Set-Content -LiteralPath (Join-Path $Dir ("seed-" + $world + ".json")) -Value $seed -Encoding UTF8
  return $world
}
$worldId = if([string]::IsNullOrWhiteSpace($World)) { Get-LatestWorld $worldsDir } else { $World }

# Gather inputs
$scenesPath = Join-Path $worldsDir ("exports/Scenes-" + $worldId + ".md")
if(!(Test-Path $scenesPath)){
  # synthesize a tiny scenes file if absent
  $stub = @("# World Scenes — " + $worldId,"","## Opening","A mysterious visitor arrives at the harbor.","")
  $dir = Split-Path -Parent $scenesPath; if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -LiteralPath $scenesPath -Value ($stub -join "`n") -Encoding UTF8
}

# Plan: TTS scripts (SSML), Translations, Packaging
$pipeline = [ordered]@{
  world = $worldId
  tts = @{
    engine = "browser-ssml"   # offline-first; cloud later via secrets
    voice  = "default"
    ssml_files = @()
  }
  translations = @()
  package = @{ outputs = @() }
}

# Create SSML per heading
$md = Get-Content -LiteralPath $scenesPath -Raw
$parts = ($md -split "(?m)^## ")
$ssmlDir = Join-Path $worldsDir "pipelines/tts"
New-Item -ItemType Directory -Force -Path $ssmlDir | Out-Null
$idx=0
foreach($p in $parts){
  $section = $p.Trim()
  if([string]::IsNullOrWhiteSpace($section)){ continue }
  $idx++
  $title, $body = if($section.Contains("`n")){ $section.Split("`n",2) } else { @("Scene "+$idx, $section) }
  $ssml = "<speak><p><s>" + [System.Web.HttpUtility]::HtmlEncode($title) + "</s></p><p>" + [System.Web.HttpUtility]::HtmlEncode($body) + "</p></speak>"
  $path = Join-Path $ssmlDir ("scene-" + $idx + ".ssml")
  Set-Content -LiteralPath $path -Value $ssml -Encoding UTF8
  $pipeline.tts.ssml_files += ("pages/apps/alexandria/worlds/pipelines/tts/scene-" + $idx + ".ssml")
}

# Translations (generate stub copies per lang offline)
$langs = @($TargetLangs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$trDir = Join-Path $worldsDir "pipelines/translations"
New-Item -ItemType Directory -Force -Path $trDir | Out-Null
foreach($lang in $langs){
  $out = Join-Path $trDir ("Scenes-" + $worldId + "." + $lang + ".md")
  # fallback: duplicate content; cloud can replace later
  Set-Content -LiteralPath $out -Value $md -Encoding UTF8
  $pipeline.translations += [ordered]@{ lang=$lang; file=("pages/apps/alexandria/worlds/pipelines/translations/Scenes-" + $worldId + "." + $lang + ".md") }
}

$pipeDir = Join-Path $worldsDir "pipelines"; if(!(Test-Path $pipeDir)){ New-Item -ItemType Directory -Force -Path $pipeDir | Out-Null }
$pipePath = Join-Path $pipeDir ("pipeline-" + $worldId + ".json")
$pipeline | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $pipePath -Encoding UTF8
Write-Host "Wrote $pipePath"
