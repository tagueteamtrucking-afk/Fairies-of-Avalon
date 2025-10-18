param(
  [string]$AssetsRoot="asset",
  [string]$OutFile="pages/apps/overseers/scene-index.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $root $AssetsRoot
$outAbs = Join-Path $root $OutFile

$vrms = @()
$vrmDirs = @("models","winged-models")
foreach($d in $vrmDirs){
  $p = Join-Path $assets $d
  if(Test-Path $p){
    $vrms += Get-ChildItem -Path $p -Filter "*.vrm" -Recurse -File | ForEach-Object { "/"+($_.FullName.Replace($root,'').TrimStart('\','/').Replace('\','/')) }
  }
}
$index = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; vrm=$vrms }
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($index | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Scene index -> $OutFile with $($vrms.Count) VRM entries"
