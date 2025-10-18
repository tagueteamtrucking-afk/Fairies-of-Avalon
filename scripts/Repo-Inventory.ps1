param(
  [string]$Root="."
)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$repo = Join-Path $here $Root

$files = Get-ChildItem -Path $repo -Recurse -File -Force | Where-Object {
  $_.FullName -notmatch "\\.git(\\|/)" # exclude .git
}
$rows = @()
foreach($f in $files){
  $rows += @{
    path = "/"+($f.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
    size = $f.Length
    modified = $f.LastWriteTimeUtc.ToString("s")+"Z"
  }
}
$out = @{
  updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
  count = $rows.Count
  files = $rows
}
$outPath = Join-Path $here "memory-history/repo-inventory.json"
$dir = Split-Path -Parent $outPath
if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outPath, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Wrote $outPath with $($rows.Count) files."
