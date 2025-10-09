$root=Split-Path -Parent $PSScriptRoot
$assets = @('asset/textures/wallpapers','asset/textures/wallpapers_optimized','asset/winged-models')
$outDir = Join-Path $root 'pages/apps/clarice/reports'; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$totalFiles=0; $totalBytes=0; $byExt=@{}
$entries=@()
foreach($d in $assets){
  $p = Join-Path $root $d
  if(Test-Path $p){
    Get-ChildItem -Path $p -File -Recurse | ForEach-Object {
      $ext = $_.Extension.ToLower()
      $size = $_.Length
      $totalFiles++ ; $totalBytes+=$size
      if(-not $byExt.ContainsKey($ext)){ $byExt[$ext]=@{count=0;bytes=0} }
      $byExt[$ext].count++ ; $byExt[$ext].bytes+=$size
    }
  }
}
$summary = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'
  total_files=$totalFiles; total_megabytes=[math]::Round($totalBytes/1MB,2)
  by_extension=$byExt.GetEnumerator() | Sort-Object Name | ForEach-Object { @{ ext=$_.Key; count=$_.Value.count; mb=[math]::Round(($_.Value.bytes/1MB),2) } }
}
$outFile = Join-Path $outDir ('graphics-audit-'+(Get-Date -Format 'yyyyMMddTHHmmssZ')+'.json')
[IO.File]::WriteAllText($outFile, ($summary | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Graphics audit -> $outFile"
