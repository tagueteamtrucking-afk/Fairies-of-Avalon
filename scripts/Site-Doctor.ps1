param(
  [Parameter()][string]$Domain = "",
  [Parameter()][object]$ApplyFixes = $false
)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1') | Out-Null
$apply = $false
try { $apply = [bool]$ApplyFixes } catch { $apply = $false }

$root = Split-Path -Parent $PSScriptRoot
$owner,$repo = ($env:GITHUB_REPOSITORY -split '/')[0..1]
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"

$cnamePath = Join-Path $root "CNAME"
$hasCname = Test-Path $cnamePath
$cnameVal = $null
if ($hasCname) {
  try { $cnameVal = (Get-Content -Raw -Path $cnamePath).Trim() } catch { $cnameVal = "" }
}
if ([string]::IsNullOrWhiteSpace($Domain) -and -not [string]::IsNullOrWhiteSpace($cnameVal)) { $Domain = $cnameVal }

$report = [ordered]@{
  repo = "$owner/$repo"
  time = $now
  domain_input = $Domain
  files = @{
    root_index   = (Test-Path (Join-Path $root 'index.html'))
    pages_dir    = (Test-Path (Join-Path $root 'pages'))
    asset_dir    = (Test-Path (Join-Path $root 'asset'))
    docs_dir     = (Test-Path (Join-Path $root 'docs'))
    nojekyll     = (Test-Path (Join-Path $root '.nojekyll'))
    cname        = $hasCname
    cname_value  = $cnameVal
    kill_sw      = (Test-Path (Join-Path $root 'kill-sw.html'))
    pages_deploy = (Test-Path (Join-Path $root '.github/workflows/pages-deploy.yml'))
  }
  pages_api = $null
  http = @()
  service_worker = @()
  planned_changes = @()
  applied_changes = @()
}

# GitHub Pages API (optional)
$tok = $env:GITHUB_TOKEN
if (-not [string]::IsNullOrWhiteSpace($tok)) {
  try {
    $headers = @{
      "Authorization" = "Bearer $tok"
      "Accept" = "application/vnd.github+json"
      "X-GitHub-Api-Version" = "2022-11-28"
      "User-Agent" = "Avalon-SiteDoctor"
    }
    $apiUrl = "https://api.github.com/repos/$owner/$repo/pages"
    $p = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers -ErrorAction Stop
    $report.pages_api = @{
      status = $p.status
      cname  = $p.cname
      https_enforced = $p.https_enforced
      build_type = $p.build_type
      source = $p.source
      custom_404 = $p.custom_404
    }
  } catch {
    $report.pages_api = @{ error = $_.Exception.Message }
  }
}

function Test-Http {
  param([string]$Url)
  try {
    $resp = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 5 -TimeoutSec 25 -Headers @{ "Cache-Control"="no-cache" } -UseBasicParsing
    return @{ url=$Url; ok=$true; status=[int]$resp.StatusCode; final=$resp.BaseResponse.ResponseUri.AbsoluteUri; server = ($resp.Headers["Server"]); via = ($resp.Headers["Via"]); }
  } catch {
    $st = $null; try { $st = $_.Exception.Response.StatusCode.Value__ } catch {}
    return @{ url=$Url; ok=$false; status=$st; error=$_.Exception.Message }
  }
}

$urls = @()
if (-not [string]::IsNullOrWhiteSpace($Domain)) {
  $urls += "https://$Domain/"
  $urls += "http://$Domain/"
  $urls += "https://$Domain/index.html?cb=$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
}
if ($owner -and $repo) {
  $urls += "https://$owner.github.io/$repo/"
}
foreach ($u in $urls) {
  $report.http += (Test-Http -Url $u)
}

if (-not [string]::IsNullOrWhiteSpace($Domain)) {
  foreach ($p in @("service-worker.js","sw.js")) {
    $u = "https://$Domain/$p"
    try { $r = Invoke-WebRequest -Uri $u -Method Get -TimeoutSec 10 -Headers @{ "Cache-Control"="no-cache" } -UseBasicParsing
      $report.service_worker += @{ path=$p; found=$true; status=[int]$r.StatusCode }
    } catch {
      $report.service_worker += @{ path=$p; found=$false }
    }
  }
}

if (-not $report.files.nojekyll) { $report.planned_changes += "add .nojekyll" }
if (-not [string]::IsNullOrWhiteSpace($Domain)) {
  if (-not $report.files.cname -or ($report.files.cname_value -ne $Domain)) { $report.planned_changes += "set CNAME -> $Domain" }
}
if (-not $report.files.kill_sw) { $report.planned_changes += "add kill-sw.html" }

if ($apply) {
  if (-not $report.files.nojekyll) {
    New-Item -ItemType File -Path (Join-Path $root '.nojekyll') -Force | Out-Null
    $report.applied_changes += "added .nojekyll"
  }
  if (-not [string]::IsNullOrWhiteSpace($Domain)) {
    $c = Join-Path $root 'CNAME'
    Set-Content -Path $c -Value $Domain -NoNewline -Encoding ascii
    $report.applied_changes += "wrote CNAME ($Domain)"
  }
  if (-not $report.files.kill_sw) {
    $kill = @"
<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Kill Service Worker</title>
<body style="font-family:system-ui;padding:24px;background:#0b0f17;color:#e5e7eb">
<h1>Kill Service Worker</h1>
<p>If a previous service worker is caching an old site, this page will unregister it and clear caches for this origin.</p>
<pre id="log"></pre>
<script>
(async()=>{const out=document.getElementById('log');function log(s){out.textContent+=s+"\\n";}
if('serviceWorker' in navigator){const regs=await navigator.serviceWorker.getRegistrations();log("Found "+regs.length+" registrations");for(const r of regs){try{await r.unregister();log("Unregistered: "+(r.active&&r.active.scriptURL||'(unknown)'));}catch(e){log("Unregister failed: "+e);}}}
if(window.caches){const names=await caches.keys();for(const n of names){await caches.delete(n);log("Deleted cache: "+n);}}
log("Done. Close this tab and reload the site.");})();
</script></body></html>
"@
    [IO.File]::WriteAllText((Join-Path $root 'kill-sw.html'), $kill, [Text.Encoding]::UTF8)
    $report.applied_changes += "added kill-sw.html"
  }
}

$diagDir = Join-Path (Join-Path $root 'pages') 'diagnostics'
$null = New-Item -ItemType Directory -Path $diagDir -Force
$reportJson = ($report | ConvertTo-Json -Depth 12)
[IO.File]::WriteAllText((Join-Path $diagDir 'site-report.json'), $reportJson, [Text.Encoding]::UTF8)
$md = @("# Site Doctor Report", "", "*Repo:* $($report.repo)", "*Time:* $now", "", "## Files", "```json", ($report.files|ConvertTo-Json -Depth 6), "```", "## Pages API", "```json", (($report.pages_api|ConvertTo-Json -Depth 6)), "```", "## HTTP checks", "```json", (($report.http|ConvertTo-Json -Depth 6)), "```", "## Service worker", "```json", (($report.service_worker|ConvertTo-Json -Depth 6)), "```", "## Planned changes", "```", ($report.planned_changes -join \"`n\"), "```", "## Applied changes", "```", ($report.applied_changes -join \"`n\"), "```") -join "`n"
[IO.File]::WriteAllText((Join-Path $diagDir 'site-report.md'), $md, [Text.Encoding]::UTF8)

Write-Host "Site Doctor complete. Report written to pages/diagnostics/site-report.{json,md}"
if ($apply) { Write-Host "Fixes applied: $($report.applied_changes -join ', ')" }
