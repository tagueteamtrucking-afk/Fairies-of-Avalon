[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string[]]$Avatars=@()
)

$ErrorActionPreference='Stop'

function Make-Slug([string]$n){ if(-not $n){return ""}; return ($n -replace '[^A-Za-z0-9]','').ToLowerInvariant() }
function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }

# Try Memory -> models.json -> VRM filenames
$memAvatars=@()
try {
  Import-Module powershell-yaml -ErrorAction Stop
  $memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
  if (Test-Path $memPath) {
    $mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml
    if ($mem.avatars_present) { $memAvatars = @($mem.avatars_present) }
  }
} catch { $memAvatars=@() }

$modelsAvatars=@()
$modelsJson = Join-Path $RepoRoot "asset/models/models.json"
if (Test-Path $modelsJson) {
  try {
    $models = Get-Content -Raw -Path $modelsJson | ConvertFrom-Json -Depth 40
    if ($models.byAvatar) { $modelsAvatars = @($models.byAvatar.PSObject.Properties.Name) }
  } catch { $modelsAvatars=@() }
}

$vrmAvatars=@()
$modelsRoot = Join-Path $RepoRoot "asset/models"
if (Test-Path $modelsRoot) {
  $vrms = Get-ChildItem $modelsRoot -Recurse -File -Filter *.vrm
  foreach($f in $vrms){
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $name = $name -replace '[_-]wings$',''  # strip *_wings/-wings suffixes
    if ($name) { $vrmAvatars += $name }
  }
  $vrmAvatars = $vrmAvatars | Sort-Object -Unique
}

# Choose source of truth in order of reliability
if (-not $Avatars -or $Avatars.Count -eq 0) {
  if ($memAvatars.Count -gt 0)       { $Avatars = $memAvatars }
  elseif ($modelsAvatars.Count -gt 0){ $Avatars = $modelsAvatars }
  else                               { $Avatars = $vrmAvatars }
}

$created = 0
foreach ($name in $Avatars) {
  if (-not $name) { continue }
  $slug = Make-Slug $name
  $appDir = Join-Path $RepoRoot ("pages/apps/{0}" -f $slug)
  New-Item -ItemType Directory -Force -Path $appDir | Out-Null
  $htmlPath = Join-Path $appDir "index.html"

  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$name · Avalon</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <script type="importmap" src="/importmap.json"></script>
  <style>
    main{max-width:1100px;margin:24px auto;padding:0 12px}
    .pill{display:inline-block;padding:.25rem .6rem;border:1px solid #999;border-radius:.6rem;font-size:.85rem;margin-right:.4rem;text-decoration:none;color:inherit}
    #viewer{width:100%;max-width:780px;height:460px;border-radius:.6rem;border:1px solid #e6e6e6;background:rgba(255,255,255,.05);margin-top:10px}
  </style>
</head>
<body>
  <main>
    <h1>$name</h1>
    <div>
      <a class="pill" href="/apps/overseers/hub/">Overseers Hub</a>
      <a class="pill" href="/apps/overseers/console.html">Console</a>
      <a class="pill" href="/apps/overseers/hub/vrm-demo.html">VRM Demo</a>
    </div>
    <div id="viewer"></div>
  </main>

  <script type="module">
    import { createVRMViewer } from '/apps/shared/vrm-viewer.js';
    import { applyWallpaperTheme } from '/apps/shared/theme.js';
    await applyWallpaperTheme({ strategy: 'first', overlay: 'dark' }).catch(()=>{});
    const NAME = ${('"'+$name+'"')};
    const models = await fetch('/asset/models/models.json?t=' + Date.now(), { cache: 'no-store' })
      .then(r=>r.json()).catch(()=>({}));
    const path = models?.byAvatar?.[NAME];
    const target = '#viewer';
    if (path) {
      await createVRMViewer({ container: target, vrmPath: '/' + String(path).replace(/^\\//,''), wingId: null, enableOrbitControls: true });
    } else {
      document.querySelector(target).innerHTML = '<p><small>No VRM mapped for this assistant yet.</small></p>';
    }
  </script>
</body>
</html>
"@
  Set-Content -Path $htmlPath -Value $html -Encoding utf8NoBOM
  $created++
}

Write-Host "Created/updated $created microapps at $(IsoNow)"
# success
exit 0
