$root=Split-Path -Parent $PSScriptRoot
$config = Get-Content -Raw -Path (Join-Path $root 'pages/apps/rooms/rooms.json') | ConvertFrom-Json
$outDir = Join-Path $root 'pages/rooms'; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
foreach($r in $config.rooms){
  $id=$r.id; $name=$r.name; $vrm=$r.vrm
  $vrmEnc=[Uri]::EscapeDataString($vrm)
  $html = @"
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>$name</title>
<link rel="stylesheet" href="/pages/apps/buildings.css">
<link rel="stylesheet" href="/pages/apps/tracy/skins/avalon-skin.css">
<header class="hero room-bg $id"><h1>$name</h1></header>
<main class="grid">
  <div class="card">
    <div class="kv"><b>Avatar</b><span class="small">If the model doesn't load, check the VRM path or upload the avatar file.</span></div>
    <iframe class="viewer" src="/pages/apps/nina/viewer.html?src=$vrmEnc"></iframe>
    <div class="kv"><b>Controls</b><span class="small">Drag to orbit. Pinch/scroll to zoom.</span></div>
  </div>
  <div class="card">
    <div class="kv"><b>Shortcuts</b>
      <a class="btn" href="/pages/plaza.html">← Back to Plaza</a>
      <a class="btn" href="/pages/apps/nina/viewer.html?src=$vrmEnc" target="_blank">Open Viewer</a>
    </div>
  </div>
</main>
"@
  $outFile = Join-Path $outDir ($id + '.html')
  [IO.File]::WriteAllText($outFile, $html, [Text.Encoding]::UTF8)
}
$links = ($config.rooms | ForEach-Object { "<li><a href='/pages/rooms/$($_.id).html'>$($_.name)</a></li>" }) -join ""
$idx = @"
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Avalon — Rooms</title>
<link rel="stylesheet" href="/pages/apps/buildings.css">
<link rel="stylesheet" href="/pages/apps/tracy/skins/avalon-skin.css">
<header class="hero"><h1>Rooms</h1></header>
<main class="card"><ul>$links</ul></main>
"@
[IO.File]::WriteAllText((Join-Path $outDir 'index.html'), $idx, [Text.Encoding]::UTF8)
Write-Host "Rooms built -> $outDir"
