param([string]$AppsDir="pages/apps",[string]$OutFile="pages/apps/_city/registry.json")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$appsAbs = Join-Path $here $AppsDir
$outAbs = Join-Path $here $OutFile
if(-not (Test-Path $appsAbs)){ Write-Error "AppsDir not found: $appsAbs"; exit 1 }
$entries = @()
$dirs = Get-ChildItem -Path $appsAbs -Directory
foreach($d in $dirs){
  $idx = Join-Path $d.FullName "index.html"
  if(Test-Path $idx){
    $id = $d.Name.ToLower()
    $name = switch($id){
      "alexandria" {"Alexandria — Library"}
      "tracy" {"Tracy — Atelier"}
      "nina" {"Nina — Lab"}
      "charlotte" {"Charlotte — Relay"}
      "stella" {"Stella — Observatory"}
      "jem" {"Jem — Dojo"}
      "carol" {"Carol — Bistro"}
      "abbey" {"Abbey — Vault"}
      "clarice" {"Clarice — Court"}
      "sorcha" {"Sorcha — Mansion"}
      "odessa" {"Odessa — Museum"}
      "themis" {"Themis — Records"}
      default { ($d.Name.Substring(0,1).ToUpper()+$d.Name.Substring(1)) }
    }
    $icon = switch($id){
      "alexandria" {"📚"}
      "tracy" {"🎨"}
      "nina" {"🧪"}
      "charlotte" {"📡"}
      "stella" {"🌌"}
      "jem" {"🐉"}
      "carol" {"🔥"}
      "abbey" {"🏦"}
      "clarice" {"⚖️"}
      "sorcha" {"🎬"}
      "odessa" {"🏛️"}
      "themis" {"📜"}
      default {"🏛️"}
    }
    $href = "/pages/apps/"+$d.Name+"/index.html"
    $entries += @{ id=$id; name=$name; icon=$icon; href=$href; desc="" }
  }
}
$out = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$entries }
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
