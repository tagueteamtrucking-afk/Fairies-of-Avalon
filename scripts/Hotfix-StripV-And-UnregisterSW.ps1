
param([Parameter()][string]$IndexFile = "index.html")
$Root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $Root $IndexFile
if (-not (Test-Path $path)) { Write-Error "Index not found: $path"; exit 1 }
$content = Get-Content -Raw -Path $path -Encoding UTF8

$marker = "<!-- AVALON-HOTFIX-STRIP-V -->"
if ($content -notmatch [regex]::Escape($marker)) {
  $snippet = @'
<!-- AVALON-HOTFIX-STRIP-V -->
<script>(function(){try{
  var u=new URL(location.href);
  if(u.searchParams.has("v")){ u.searchParams.delete("v"); history.replaceState(null,"",u.toString()); }
  if("serviceWorker" in navigator){
    navigator.serviceWorker.getRegistrations()
      .then(rs=>Promise.all(rs.map(r=>r.unregister())))
      .catch(()=>{});
    if(navigator.serviceWorker.controller){ navigator.serviceWorker.controller.postMessage({type:"AVALON_UNREGISTER"}); }
  }
}catch(e){}})();</script>
'@

  # Insert right after <head> or at top
  if ($content -match "<head[^>]*>") {
    $content = $content -replace "(<head[^>]*>)", ('$1' + "`n" + $snippet)
  } else {
    $content = $snippet + "`n" + $content
  }
  Set-Content -Path $path -Value $content -NoNewline -Encoding UTF8
  Write-Host "Hotfix injected into $IndexFile"
} else {
  Write-Host "Hotfix already present in $IndexFile"
}
