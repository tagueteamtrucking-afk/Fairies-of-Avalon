\
param([string]$AppsDir="pages/apps",[string]$OutFile="pages/apps/_city/registry.json")
$ErrorActionPreference="Stop"
$root = $PSScriptRoot
$appsAbs = Join-Path $root $AppsDir
$outAbs = Join-Path $root $OutFile
$items = @()
if(Test-Path $appsAbs){
  $dirs = Get-ChildItem -Path $appsAbs -Directory | Where-Object { $_.Name.ToLower() -ne "odessa" } # remove Odessa
  foreach($d in $dirs){
    $idx = Join-Path $d.FullName "index.html"
    if(Test-Path $idx){
      $rel = "/"+($idx.Replace($root,"").TrimStart('\','/').Replace('\','/'))
      $name = $d.Name
      $title = switch ($name.ToLower()) {
        "alexandria" {"Alexandria — Gothic Library"}
        "charlotte" {"Charlotte — Relay Tower"}
        "nina" {"Nina — Futuristic Lab"}
        "tracy" {"Tracy — Cathedral Studio"}
        "carol" {"Carol — Restaurant"}
        "jem" {"Jem — Dojo"}
        "stella" {"Stella — Observatory"}
        "abbey" {"Abbey — Grand Vault"}
        "themis" {"Themis — Record Hall"}
        "billie" {"Billie — Gold Mansion"}
        "sorcha" {"Sorcha — Mansion & Pool"}
        "clarice" {"Clarice — Courtroom & Palace"}
        default { $name }
      }
      $desc = switch ($name.ToLower()) {
        "alexandria" {"DM & Worldbuilding (with Voice DM)"}
        "charlotte" {"Design & Pipelines"}
        "nina" {"3D & VRM"}
        "tracy" {"Artboards & Wallpapers"}
        "carol" {"Meal Plans & Shopping"}
        "jem" {"Coaching & Biometrics"}
        "stella" {"Meditations & Gateway Practice"}
        "abbey" {"Finance & Reports"}
        "themis" {"Compliance & Reminders"}
        "billie" {"Monetization & Shops"}
        "sorcha" {"Social Video & Storyboards (incl. 18+ hidden track)"}
        "clarice" {"Security & Backups"}
        default { "" }
      }
      $items += @{ name=$name; title=$title; desc=$desc; href=$rel }
    }
  }
}
$doc = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$items }
$enc = New-Object System.Text.UTF8Encoding($false)  # UTF-8 no BOM (BOM caused Node JSON error)
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), $enc)
