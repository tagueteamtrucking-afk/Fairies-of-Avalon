param(
  [string]$AppsDir="pages/apps",
  [string]$OutFile="pages/apps/_city/registry.json"
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $PSScriptRoot
$appsAbs = Join-Path $here $AppsDir
$outAbs = Join-Path $here $OutFile
$items = @()

if(Test-Path -LiteralPath $appsAbs){
  $dirs = Get-ChildItem -LiteralPath $appsAbs -Directory | Where-Object { $_.Name.ToLower() -ne "odessa" }
  foreach($d in $dirs){
    $idx = Join-Path $d.FullName "index.html"
    if(Test-Path -LiteralPath $idx){
      $rel = "/"+($idx.Replace($here,"").TrimStart('\','/').Replace('\','/'))
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
        "alexandria" {"DM & Worldbuilding (Voice DM available)"}
        "charlotte" {"Design & Pipelines"}
        "nina" {"3D & VRM"}
        "tracy" {"Artboards & Wallpapers"}
        "carol" {"Meal Plans & Shopping"}
        "jem" {"Coaching & Biometrics"}
        "stella" {"Meditations & Gateway Practice"}
        "abbey" {"Finance & Reports"}
        "themis" {"Compliance & Reminders"}
        "billie" {"Monetization & Shops"}
        "sorcha" {"Social Video (incl. 18+ hidden track)"} 
        "clarice" {"Security & Backups"}
        default { "" }
      }
      $items += @{ name=$name; title=$title; desc=$desc; href=$rel }
    }
  }
}
$doc = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; items=$items }
$enc = New-Object System.Text.UTF8Encoding($false)  # no BOM
$dir = Split-Path -Parent $outAbs; if(-not (Test-Path -LiteralPath $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), $enc)
