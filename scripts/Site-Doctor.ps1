
param([string]$Domain = "",[object]$ApplyFixes = $false)
function To-Bool($x) { try { [bool]$x } catch { $false } }
$apply = To-Bool $ApplyFixes
$root  = Split-Path -Parent $PSScriptRoot
$owner=$null;$repo=$null
if ($env:GITHUB_REPOSITORY) { try { $sp=$env:GITHUB_REPOSITORY -split '/'; if($sp.Length -ge 2){$owner=$sp[0];$repo=$sp[1]} } catch {} }
$cnamePath = Join-Path $root 'CNAME'; $cnameVal=""; if (Test-Path $cnamePath) { try { $cnameVal=(Get-Content -Raw -Path $cnamePath).Trim() } catch {} }
if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = $cnameVal }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$report = [ordered]@{ repo= if($owner){"$owner/$repo"}else{"(unknown)"}; time=$now; domain_input=$Domain;
  files=@{ root_index=(Test-Path (Join-Path $root 'index.html')); pages_dir=(Test-Path (Join-Path $root 'pages')); asset_dir=(Test-Path (Join-Path $root 'asset')); docs_dir=(Test-Path (Join-Path $root 'docs')); nojekyll=(Test-Path (Join-Path $root '.nojekyll')); cname=(Test-Path $cnamePath); cname_value=$cnameVal; kill_sw=(Test-Path (Join-Path $root 'kill-sw.html')); pages_deploy=(Test-Path (Join-Path $root '.github/workflows/deploy-pages.yml')) };
  http=@(); planned_changes=@(); applied_changes=@(); errors=@() }
function Test-Http([string]$Url){ try { $r=Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 5 -TimeoutSec 25 -Headers @{"Cache-Control"="no-cache"} -UseBasicParsing; return @{url=$Url; ok=$true; status=[int]$r.StatusCode; final=$r.BaseResponse.ResponseUri.AbsoluteUri; server=$r.Headers["Server"]; via=$r.Headers["Via"]} } catch { $st=$null; try{$st=$_.Exception.Response.StatusCode.Value__}catch{}; return @{url=$Url; ok=$false; status=$st; error=$_.Exception.Message} } }
$urls=@(); if (-not [string]::IsNullOrWhiteSpace($Domain)){ $urls+=("https://{0}/" -f $Domain); $urls+=("http://{0}/" -f $Domain) }
foreach($u in $urls){ $report.http += (Test-Http -Url $u) }
if (-not $report.files.nojekyll) { $report.planned_changes += "add .nojekyll" }
if (-not [string]::IsNullOrWhiteSpace($Domain)) { if (-not $report.files.cname -or ($report.files.cname_value -ne $Domain)) { $report.planned_changes += ("set CNAME -> {0}" -f $Domain) } }
if (-not $report.files.kill_sw) { $report.planned_changes += "add kill-sw.html" }
if ($apply) { try {
  if (-not $report.files.nojekyll){ New-Item -ItemType File -Path (Join-Path $root '.nojekyll') -Force | Out-Null; $report.applied_changes += "added .nojekyll" }
  if (-not [string]::IsNullOrWhiteSpace($Domain)){ Set-Content -Path (Join-Path $root 'CNAME') -Value $Domain -NoNewline -Encoding ascii; $report.applied_changes += ("wrote CNAME ({0})" -f $Domain) }
  if (-not $report.files.kill_sw){
    $kill='<!doctype html><meta charset="utf-8"><title>Kill SW</title><body style="font-family:system-ui;padding:24px"><h1>Kill Service Worker</h1><pre id="log"></pre><script>(async()=>{const o=document.getElementById("log");const log=s=>o.textContent+=s+"\n";if("serviceWorker"in navigator){const r=await navigator.serviceWorker.getRegistrations();log("Found "+r.length+" registrations");for(const a of r){try{await a.unregister();log("Unregistered: "+(a.active&&a.active.scriptURL||"(unknown)"));}catch(e){log("Unregister failed: "+e);}}}if(window.caches){const n=await caches.keys();for(const k of n){await caches.delete(k);log("Deleted cache: "+k);}}log("Done. Close this tab and reload the site.");})();</script></body>';
    [IO.File]::WriteAllText((Join-Path $root 'kill-sw.html'), $kill, [Text.Encoding]::UTF8); $report.applied_changes += "added kill-sw.html"
  }
} catch { $report.errors += ("Apply fixes failed: "+$_.Exception.Message) } }
$diagDir = Join-Path (Join-Path $root 'pages') 'diagnostics'; $null = New-Item -ItemType Directory -Path $diagDir -Force
[IO.File]::WriteAllText((Join-Path $diagDir 'site-report.json'), ($report|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host "Site Doctor complete."
exit 0
