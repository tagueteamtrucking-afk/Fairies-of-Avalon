$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
function Write-Text($rel,$txt){
  $abs = Join-Path $here $rel
  $dir = Split-Path -Parent $abs
  if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($abs, $txt, [Text.Encoding]::UTF8)
  Write-Host "Wrote $rel"
}
$html = @'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Avalon — Launching…</title>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<style>
  html,body{margin:0;height:100%;background:#0b1220;color:#e5e7eb;font-family:system-ui,Segoe UI,Roboto}
  main{display:flex;align-items:center;justify-content:center;height:100%;flex-direction:column;gap:12px}
  .btn{color:#e5e7eb;border:1px solid #334155;border-radius:10px;padding:8px 12px;text-decoration:none}
  .muted{opacity:.75;font-size:12px}
</style>
</head>
<body>
<main>
  <h1>🏰 Avalon</h1>
  <p class="muted">Launching City Plaza…</p>
  <p><a class="btn" id="fallback" href="/pages/apps/_city/index.html">Open City Plaza</a></p>
</main>
<script>
(async function(){
  try{
    if('serviceWorker' in navigator){
      const regs = await navigator.serviceWorker.getRegistrations();
      for(const r of regs){ await r.unregister(); }
      if(window.caches){
        const keys = await caches.keys();
        for(const k of keys){ await caches.delete(k); }
      }
    }
  }catch(e){}
  const target = "/pages/apps/_city/index.html";
  const url = new URL(target, location.origin);
  url.searchParams.set("cb", Date.now().toString(36));
  location.replace(url.toString());
})();
</script>
<noscript>
  <meta http-equiv="refresh" content="0; url=/pages/apps/_city/index.html">
</noscript>
</body>
</html>

'@
$kill = @'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kill SW — Boost</title><style>body{background:#0b1220;color:#e5e7eb;font-family:system-ui,Segoe UI,Roboto;margin:0;padding:16px}</style></head>
<body><h1>Service Worker & Cache Reset</h1><pre id="log">Running…</pre>
<script>
(async()=>{
  const lines=[]; const log=(m)=>{lines.push(m); document.getElementById('log').textContent = lines.join("\n");};
  try{
    if('serviceWorker' in navigator){
      const regs = await navigator.serviceWorker.getRegistrations();
      for(const r of regs){ await r.unregister(); log("Unregistered: "+(r.scope||"(scope)")); }
    } else { log("No serviceWorker API"); }
    if(window.caches){
      const keys = await caches.keys();
      for(const k of keys){ await caches.delete(k); log("Cache deleted: "+k); }
    } else { log("No caches API"); }
  }catch(e){ log("Error: "+e); }
  log("Done. Reloading…");
  setTimeout(()=>location.href="/?cb="+Date.now().toString(36), 800);
})();
</script></body></html>
'@
Write-Text "index.html" $html
Write-Text "pages/index.html" $html
Write-Text "pages/apps/index.html" $html
Write-Text "kill-sw-boost.html" $kill
