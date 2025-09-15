[CmdletBinding()]
param(
  [string]$RepoRoot = ".",
  [string[]]$Avatars
)

$ErrorActionPreference = 'Stop'

try { Import-Module powershell-yaml -ErrorAction Stop }
catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function Make-Slug([string]$name) {
  if (-not $name) { return "" }
  return ($name -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}

$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml
$appsRoot = Join-Path $RepoRoot ($mem.hosting.microapps_path)
if (-not (Test-Path $appsRoot)) { New-Item -ItemType Directory -Force -Path $appsRoot | Out-Null }

if (-not $Avatars -or $Avatars.Count -eq 0) { $Avatars = @($mem.avatars_present) }

foreach ($name in $Avatars) {
  $slug = Make-Slug $name
  if (-not $slug) { continue }
  $dir  = Join-Path $appsRoot $slug
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $title = "Avalon — $name"
  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$title</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <style>
    main{max-width:920px;margin:24px auto;padding:0 12px}
    .pill{display:inline-block;padding:.25rem .6rem;border:1px solid #999;border-radius:.6rem;font-size:.85rem}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px;margin-top:12px}
    .card{border:1px solid #eee;border-radius:.6rem;padding:12px}
    small{color:#666}
  </style>
</head>
<body>
  <main>
    <h1>$name</h1>
    <div>
      <a class="pill" href="/apps/overseers/hub/">Overseers Hub</a>
      <a class="pill" href="/apps/overseers/console.html">Overseers Console</a>
    </div>

    <section class="card">
      <h3>Status</h3>
      <p>Hello—I'm <b>$name</b>. This is my <i>microapp skeleton</i>. The Overseers will connect my features soon.</p>
      <p><small id="status">Loading project status…</small></p>
    </section>
  </main>
  <script src="./app.js" defer></script>
</body>
</html>
"@

  $js = @"
(async ()=>{
  async function fetchJSON(u){ const r=await fetch(u+'?t='+Date.now(),{cache:'no-store'}); if(!r.ok) throw new Error(u+': '+r.status); return r.json(); }
  try{
    const prog = await fetchJSON('/apps/overseers/progress.json');
    const caps = await fetchJSON('/apps/overseers/capabilities.json');
    const el = document.getElementById('status');
    const done = (prog?.totals?.success||0)+(prog?.totals?.failed||0)+(prog?.totals?.skipped||0);
    const total = done + (prog?.pending||0);
    el.textContent = `Queue: ${done}/${total} processed · last run ${prog?.last_run||'—'} · AI Core ${caps?.ai_core?.status||'—'}`;
  }catch(e){
    document.getElementById('status').textContent = 'Status unavailable';
    console.warn(e);
  }
})();
"@

  Set-Content -Path (Join-Path $dir "index.html") -Value $html -Encoding utf8NoBOM
  Set-Content -Path (Join-Path $dir "app.js")    -Value $js   -Encoding utf8NoBOM
}
Write-Host "Microapps created/updated for $($Avatars.Count) assistants."
