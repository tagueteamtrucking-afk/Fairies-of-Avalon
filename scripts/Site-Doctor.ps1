param(
  [Parameter()][string]$Domain = "",
  [Parameter()][object]$ApplyFixes = $false
)
# Robust version: never throws; always writes a report; exits 0.
# If no domain is supplied and no CNAME file, we still test the org pages URL.
try {
  Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1') -ErrorAction SilentlyContinue | Out-Null
} catch {}

$apply = $false
try { $apply = [bool]$ApplyFixes } catch { $apply = $false }

$root = Split-Path -Parent $PSScriptRoot
$owner,$repo = $null,$null
if ($env:GITHUB_REPOSITORY) {
  try { $split = $env:GITHUB_REPOSITORY -split '/'; $owner=$split[0]; $repo=$split[1] } catch {}
}

$cnamePath = Join-Path $root "CNAME"
$cnameVal = ""
if (Test-Path $cnamePath) {
  try { $cnameVal = (Get-Content -Raw -Path $cnamePath).Trim() } catch {}
}
if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = $cnameVal }

$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$report = [ordered]@{
  repo = if($owner){ "$owner/$repo" } else { "(unknown)" }
  time = $now
  domain_input = $Domain
  files = @{
    root_index   = (Test-Path (Join-Path $root 'index.html'))
    pages_dir    = (Test-Path (Join-Path $root 'pages'))
    asset_dir    = (Test-Path (Join-Path $root 'asset'))
    docs_dir     = (Test-Path (Join-Path $root 'docs'))
    nojekyll     = (Test-Path (Join-Path $root '.nojekyll'))
    cname        = (Test-Path $cnamePath)
    cname_value  = $cnameVal
    kill_sw      = (Test-Path (Join-Path $root 'kill-sw.html'))
    pages_deploy = (Test-Path (Join-Path $root '.github/workflows/pages-deploy.yml'))
  }
  pages_api = $null
  http = @()
  service_worker = @()
  planned_changes = @()
  applied_changes = @()
  errors = @()
}

function Add-Err([string]$m){ $report.errors += $m; Write-Warning $m }

# Pages API
if ($owner -and $repo -and $env:GITHUB_TOKEN) {
  try {
    $headers = @{
      "Authorization" = "Bearer $($env:GITHUB_TOKEN)"
      "Accept" = "application/vnd.github+json"
      "X-GitHub-Api-Version" = "2022-11-28"
      "User-Agent" = "Avalon-SiteDoctor"
    }
    $apiUrl = "https://api.github.com/repos/$owner/$repo/pages"
    $p = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers -ErrorAction Stop
    $report.pages_api = @{ status=$p.status; cname=$p.cname; https_enforced=$p.https_enforced; build_type=$p.build_type; source=$p.source; custom_404=$p.custom_404 }
  } catch { Add-Err "Pages API read failed: $($_.Exception.Message)" }
}

function Test-Http($Url){
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
}
if ($owner -and $repo) {
  $urls += "https://$owner.github.io/$repo/"
}
foreach($u in $urls){ $report.http += (Test-Http $u) }

# Planned fixes
if (-not $report.files.nojekyll) { $report.planned_changes += "add .nojekyll" }
if (-not [string]::IsNullOrWhiteSpace($Domain)) {
  if (-not $report.files.cname -or ($report.files.cname_value -ne $Domain)) { $report.planned_changes += "set CNAME -> $Domain" }
}
if (-not $report.files.kill_sw) { $report.planned_changes += "add kill-sw.html" }

# Apply
if ($apply) {
  try {
    if (-not $report.files.nojekyll) {
      New-Item -ItemType File -Path (Join-Path $root '.nojekyll') -Force | Out-Null
      $report.applied_changes += "added .nojekyll"
    }
    if (-not [string]::IsNullOrWhiteSpace($Domain)) {
      Set-Content -Path (Join-Path $root 'CNAME') -Value $Domain -NoNewline -Encoding ascii
      $report.applied_changes += "wrote CNAME ($Domain)"
    }
    if (-not $report.files.kill_sw) {
      $kill = @"
<!doctype html>
<html lang='en'><meta charset='utf-8'><title>Kill Service Worker</title>
<body style='font-family:system-ui;padding:24px;background:#0b0f17;color:#e5e7eb'>
<h1>Kill Service Worker</h1>
<pre id='log'></pre>
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
  } catch { Add-Err "Apply fixes failed: $($_.Exception.Message)" }
}

# Save report
try {
  $diagDir = Join-Path (Join-Path $root 'pages') 'diagnostics'
  $null = New-Item -ItemType Directory -Path $diagDir -Force
  [IO.File]::WriteAllText((Join-Path $diagDir 'site-report.json'), ($report|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
  $md = @("# Site Doctor Report", "", "*Repo:* $($report.repo)", "*Time:* $now", "", "## Files", "```json", ($report.files|ConvertTo-Json -Depth 6), "```", "## Pages API", "```json", (($report.pages_api|ConvertTo-Json -Depth 6)), "```", "## HTTP checks", "```json", (($report.http|ConvertTo-Json -Depth 6)), "```", "## Planned changes", "```", ($report.planned_changes -join \"`n\"), "```", "## Applied changes", "```", ($report.applied_changes -join \"`n\"), "```", "## Errors", "```", ($report.errors -join \"`n\"), "```") -join "`n"
  [IO.File]::WriteAllText((Join-Path $diagDir 'site-report.md'), $md, [Text.Encoding]::UTF8)
  Write-Host "Site Doctor complete."
} catch {
  Write-Warning "Failed to save report: $($_.Exception.Message)"
}

exit 0
