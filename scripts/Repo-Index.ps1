param(
  [string]$Root = ".",
  [string]$OutFile = "memory-history/repo-index.json"
)
$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path $Root).Path
$all = Get-ChildItem -Path $rootPath -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($rootPath.Length).TrimStart('\','/').Replace('\','/')
  [PSCustomObject]@{
    path = $rel
    size = $_.Length
    sha1 = (Get-FileHash -Algorithm SHA1 -Path $_.FullName).Hash
    mtime = $_.LastWriteTimeUtc.ToString("o")
  }
}
$index = [PSCustomObject]@{
  created = (Get-Date).ToString("o")
  count   = $all.Count
  files   = $all
}
$dir = Split-Path -Parent $OutFile
if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$index | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "Wrote repo index to $OutFile with $($all.Count) files."
