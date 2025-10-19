param([string]$AppsDir="pages/apps",[string]$OutFile="pages/apps/_city/registry.json")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$appsAbs = Join-Path $here $AppsDir
$outAbs = Join-Path $here $OutFile
$items = @()
if(Test-Path $appsAbs){
  $dirs = Get-ChildItem -Path $appsAbs -Directory
  foreach($d in $dirs){
    # pick index.html inside each app folder
    $idx = Join-Path $d.FullName "index.html"
    if(Test-Path $idx){
      $rel = "/"+($idx.Replace($here,'').TrimStart('\','/').Replace('\','/'))
      $items += @{ name=$d.Name; href=$rel; icon="🏛️" }
    }
  }
}
$doc = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$items }
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
