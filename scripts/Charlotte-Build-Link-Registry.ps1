param([string]$AppsDir="pages/apps",[string]$OutFile="pages/apps/_city/registry.json")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$appsAbs = Join-Path $here $AppsDir
$outAbs = Join-Path $here $OutFile
$items = @()
if(Test-Path $appsAbs){
  $dirs = Get-ChildItem -Path $appsAbs -Directory
  foreach($d in $dirs){
    $idx = Join-Path $d.FullName "index.html"
    if(Test-Path $idx){
      $rel = "/"+($idx.Replace($here,"").TrimStart('\','/').Replace('\','/'))
      $name = $d.Name
      $desc = switch ($name.ToLower()) {
        "alexandria" {"Gothic Library — DM & Worldbuilding"}
        "charlotte" {"Relay Tower — Design & Pipelines"}
        "nina" {"Futuristic Lab — 3D & VRM"}
        "tracy" {"Cathedral Studio — Artboards"}
        "carol" {"Restaurant — Meal Plans"}
        "jem" {"Dojo — Coaching"}
        "stella" {"Observatory — Audio"}
        "abbey" {"Grand Vault — Finance"}
        "themis" {"Record Hall — Compliance"}
        "billie" {"Gold Mansion — Monetization"}
        "sorcha" {"Mansion & Pool — Social Video"}
        "clarice" {"Courtroom & Palace — Security"}
        "odessa" {"Museum — Research"}
        default {""}
      }
      $items += @{ name=$name; desc=$desc; href=$rel }
    }
  }
}
$doc = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$items }
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
