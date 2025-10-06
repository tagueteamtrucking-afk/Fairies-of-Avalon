param([Parameter()][string]$Domain = "",[Parameter()][object]$ApplyFixes = $false)
function To-Bool($x) { try { [bool]$x } catch { $false } }
$apply = To-Bool $ApplyFixes
$root  = Split-Path -Parent $PSScriptRoot
$owner=$null;$repo=$null
if ($env:GITHUB_REPOSITORY) { try { $sp=$env:GITHUB_REPOSITORY -split '/'; if($sp.Length -ge 2){$owner=$sp[0];$repo=$sp[1]} } catch {} }
$cnamePath = Join-Path $root 'CNAME'; $cnameVal=""; if (Test-Path $cnamePath) { try { $cnameVal=(Get-Content -Raw -Path $cnamePath).Trim() } catch {} }
if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = $cnameVal }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$report = [ordered]@{ repo= if($owner){"$owner/$repo"}else{"(unknown)"}; time=$now; domain_input=$Domain;
  files=@{ root_index=(Test-Path (Join-Path $root 'index.html')); pages_dir=(Test-Path (Join-Path $root 'pages')); asset_dir=(Test-Path (Join-Path $root 'asset'));
  docs_dir=(Test-Path (Join-Path $root 'docs')); nojekyll=(Test-Path (Join-Path $root '.nojekyll')); cname=(Test-Path $cnamePath); cname_value=$cnameVal;
  kill_sw=(Test-Path (Join-Path $root 'kill-sw.html')); pages_deploy=(Test-Path (Join-Path $root '.github/workflows/pages-deploy.yml')) };
  pages_api=$null; http=@(); planned_changes=@(); applied_changes=@(); errors=@() }
function Add-Err([string]$m){ $script:report.errors += $m; Write-Warning $m }
if ($owner -and $repo -and $env:GITHUB_TOKEN) { try {
  $h=@{"Authorization"="Bearer $($env:GITHUB_TOKEN)";"Accept"="application/vnd.github+json";"X-GitHub-Api-Version"="2022-11-28";"User-Agent"="Avalon-SiteDoctor"}
  $p=Invoke-RestMethod -Method Get -Uri ("https://api.github.com/repos/{0}/{1}/pages" -f $owner,$repo) -Headers $h -ErrorAction Stop
  $report.pages_api=@{status=$p.status;cname=$p.cname;https_enforced=$p.https_enforced;build_type=$p.build_type;source=$p.source;custom_404=$p.custom_404}
} catch { Add-Err ("Pages API read failed: "+$_.Exception.Message) } }
function Test-Http([string]$Url){ try { $r=Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 5 -TimeoutSec 25 -Headers @{"Cache-Control"="no-cache"} -UseBasicParsing
  return @{url=$Url; ok=$true; status=[int]$r.StatusCode; final=$r.BaseResponse.ResponseUri.AbsoluteUri; server=$r.Headers["Server"]; via=$r.Headers["Via"]} }
  catch { $st=$null; try{$st=$_.Exception.Response.StatusCode.Value__}catch{}; return @{url=$Url; ok=$false; status=$st; error=$_.Exception.Message} } }
$urls=@(); if (-not [string]::IsNullOrWhiteSpace($Domain)){ $urls+=("https://{0}/" -f $Domain); $urls+=("http://{0}/" -f $Domain) }
if ($owner -and $repo){ $urls+=("https://{0}.github.io/{1}/" -f $owner,$repo) }
foreach($u in $urls){ $report.http += (Test-Http -Url $u) }
if (-not $report.files.nojekyll) { $report.planned_changes += "add .nojekyll" }
if (-not [string]::IsNullOrWhiteSpace($Domain)) { if (-not $report.files.cname -or ($report.files.cname_value -ne $Domain)) { $report.planned_changes += ("set CNAME -> {0}" -f $Domain) } }
if (-not $report.files.kill_sw) { $report.planned_changes += "add kill-sw.html" }
if ($apply) { try {
  if (-not $report.files.nojekyll){ New-Item -ItemType File -Path (Join-Path $root '.nojekyll') -Force | Out-Null; $report.applied_changes += "added .nojekyll" }
  if (-not [string]::IsNullOrWhiteSpace($Domain)){ Set-Content -Path (Join-Path $root 'CNAME') -Value $Domain -NoNewline -Encoding ascii; $report.applied_changes += ("wrote CNAME ({0})" -f $Domain) }
  if (-not $report.files.kill_sw){ $kill=@"
<!doctype html><html lang='en'><meta charset='utf-8'><title>Kill Service Worker</title>
<body style='font-family:system-ui;padding:24px;background:#0b0f17;color:#e5e7eb'>
<h1>Kill Service Worker</h1><pre id='log'></pre>
<script>(async()=>{const o=document.getElementById('log');const log=s=>o.textContent+=s+"\\n";
if('serviceWorker'in navigator){const r=await navigator.serviceWorker.getRegistrations();log("Found "+r.length+" registrations");for(const a of r){try{await a.unregister();log("Unregistered: "+(a.active&&a.active.scriptURL||'(unknown)'));}catch(e){log("Unregister failed: "+e);}}}
if(window.caches){const n=await caches.keys();for(const k of n){await caches.delete(k);log("Deleted cache: "+k);}}
log("Done. Close this tab and reload the site.");})();</script></body></html>
"@; [IO.File]::WriteAllText((Join-Path $root 'kill-sw.html'), $kill, [Text.Encoding]::UTF8); $report.applied_changes += "added kill-sw.html" }
} catch { Add-Err ("Apply fixes failed: "+$_.Exception.Message) } }
try{
  $diagDir = Join-Path (Join-Path $root 'pages') 'diagnostics'; $null = New-Item -ItemType Directory -Path $diagDir -Force
  [IO.File]::WriteAllText((Join-Path $diagDir 'site-report.json'), ($report|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
  $md = "# Site Doctor Report`n`n*Repo:* {0}`n*Time:* {1}`n`n## Files`n```json`n{2}`n````n## Pages API`n```json`n{3}`n````n## HTTP checks`n```json`n{4}`n````n## Planned changes`n```\n{5}\n````n## Applied changes`n```\n{6}\n````n## Errors`n```\n{7}\n```" -f $report.repo,$now,($report.files|ConvertTo-Json -Depth 6),(($report.pages_api|ConvertTo-Json -Depth 6)),(($report.http|ConvertTo-Json -Depth 6)),($report.planned_changes -join "`n"),($report.applied_changes -join "`n"),($report.errors -join "`n")
  [IO.File]::WriteAllText((Join-Path $diagDir 'site-report.md'), $md, [Text.Encoding]::UTF8)
  Write-Host "Site Doctor complete."
} catch { Write-Warning ("Failed to save report: "+$_.Exception.Message) }
exit 0
