
param([string]$Domain = "", [object]$ApplyFixes = $true)
function To-Bool($x){ if($x -is [bool]){return $x}; $s=""+$x; if([string]::IsNullOrWhiteSpace($s)){return $false}; $s=$s.Trim().ToLower(); return @("1","true","yes","y","on") -contains $s }
$apply = To-Bool $ApplyFixes
$Root = Split-Path -Parent $PSScriptRoot
$cnamePath = Join-Path $Root 'CNAME'
$hasNoJekyll = Test-Path (Join-Path $Root '.nojekyll')
$hasKill = Test-Path (Join-Path $Root 'kill-sw.html')
$cnameCurrent = if (Test-Path $cnamePath) { (Get-Content -Raw -Path $cnamePath).Trim() } else { "" }
if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = $cnameCurrent }

$planned = @()
if (-not $hasNoJekyll) { $planned += "add .nojekyll" }
if ($Domain -and $Domain -ne $cnameCurrent) { $planned += "set CNAME -> $Domain" }
if (-not $hasKill) { $planned += "add kill-sw.html" }

if ($apply) {
  if (-not $hasNoJekyll) { New-Item -ItemType File -Path (Join-Path $Root '.nojekyll') -Force | Out-Null }
  if ($Domain) { Set-Content -Path $cnamePath -Value $Domain -NoNewline -Encoding ascii }
  if (-not $hasKill) {
    $html = '<!doctype html><meta charset="utf-8"><title>Kill SW</title><body style="font-family:system-ui;padding:24px"><h1>Kill Service Worker</h1><pre id="log"></pre><script>(async()=>{const o=document.getElementById("log");const log=s=>o.textContent+=s+" \n";if("serviceWorker"in navigator){const r=await navigator.serviceWorker.getRegistrations();log("Found "+r.length+" registrations");for(const a of r){try{await a.unregister();log("Unregistered: "+(a.active&&a.active.scriptURL||"(unknown)"));}catch(e){log("Unregister failed: "+e);}}}if(window.caches){const n=await caches.keys();for(const k of n){await caches.delete(k);log("Deleted cache: "+k);}}log("Done. Close this tab and reload the site.");})();</script></body>'
    Set-Content -Path (Join-Path $Root 'kill-sw.html') -Value $html -NoNewline -Encoding UTF8
  }
}

$diagDir = Join-Path (Join-Path $Root 'pages') 'diagnostics'
New-Item -ItemType Directory -Path $diagDir -Force | Out-Null
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'
$report = @{ updated=$now; domain=$Domain; planned=$planned; applied=$apply }
[IO.File]::WriteAllText((Join-Path $diagDir 'site-report.json'), ($report|ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Site Doctor complete."
