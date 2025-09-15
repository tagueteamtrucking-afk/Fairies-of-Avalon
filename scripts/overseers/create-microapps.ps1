[CmdletBinding()]
param([string]$RepoRoot=".", [string[]]$Avatars=@())

$ErrorActionPreference='Stop'

function Make-Slug([string]$n){ if(-not $n){return ""}; return ($n -replace '[^A-Za-z0-9]','').ToLowerInvariant() }
function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }

# Load Memory for default avatars if none provided
$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem = @{}
try {
  Import-Module powershell-yaml -ErrorAction Stop
  $mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml
} catch { $mem=@{} }

if (-not $Avatars -or $Avatars.Count -eq 0) {
  if ($mem.avatars_present) { $Avatars = @($mem.avatars_present) } else { $Avatars = @() }
}

# Try to use models.json mapping at runtime in the page (simpler here)
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
      await createVRMViewer({ container: target, vrmPath: '/' + path.replace(/^\\//,''), wingId: null, enableOrbitControls: true });
    } else {
      document.querySelector(target).innerHTML = '<p><small>No VRM found for this assistant yet.</small></p>';
    }
  </script>
</body>
</html>
"@
  Set-Content -Path $htmlPath -Value $html -Encoding utf8NoBOM
  $created++
}

Write-Host "Created/updated $created microapps at $(Get-Date -Format 'u')."
