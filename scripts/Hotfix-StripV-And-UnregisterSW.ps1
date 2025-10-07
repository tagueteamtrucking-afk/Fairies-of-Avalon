param([string]$IndexFile="index.html")
$Root=Split-Path -Parent $PSScriptRoot; $p=Join-Path $Root $IndexFile
$h='<!-- AVALON-HOTFIX-STRIP-V -->'
$t=Get-Content -Raw -Path $p -Encoding UTF8
if($t -notmatch [regex]::Escape($h)){
 $s=@'<!-- AVALON-HOTFIX-STRIP-V --><script>(function(){try{var u=new URL(location.href);if(u.searchParams.has("v")){u.searchParams.delete("v");history.replaceState(null,"",u.toString());}if("serviceWorker"in navigator){navigator.serviceWorker.getRegistrations().then(rs=>Promise.all(rs.map(r=>r.unregister()))).catch(()=>{});}}catch(e){}})();</script>'@
 $t=$t -replace "(<head[^>]*>)",("$1`n"+$s); Set-Content -Path $p -Encoding UTF8 -NoNewline -Value $t
}
