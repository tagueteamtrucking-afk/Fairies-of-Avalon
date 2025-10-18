param(
  [string]$AppsRoot='pages/apps',
  [string]$OutFile='pages/apps/_city/registry.json'
)
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
$appsAbs = Join-Path $root $AppsRoot
$outAbs = Join-Path $root $OutFile
if(-not (Test-Path $appsAbs)){ Write-Error "Apps root not found: $appsAbs"; exit 1 }

$items=@()
$dirs = Get-ChildItem -Path $appsAbs -Directory
foreach($d in $dirs){
  if($d.Name -eq '_city' -or $d.Name -eq '_ui'){ continue }
  $index = Join-Path $d.FullName 'index.html'
  if(Test-Path $index){
    $id = $d.Name
    $name = switch ($id){
      'alexandria' {'Alexandria — Library'}
      'tracy' {'Tracy — Atelier'}
      'nina' {'Nina — Lab'}
      'charlotte' {'Charlotte — Relay'}
      'stella' {'Stella — Observatory'}
      'jem' {'Jem — Dojo'}
      'carol' {'Carol — Bistro'}
      'abbey' {'Abbey — Vault'}
      'clarice' {'Clarice — Court'}
      'sorcha' {'Sorcha — Mansion'}
      'odessa' {'Odessa — Museum'}
      'themis' {'Themis — Records'}
      'whitestar' {'White Star — Palace'}
      'reyczar' {'Rey Czar — Palace'}
      default { $id }
    }
    $icon = switch ($id){
      'alexandria' {'📚'} 'tracy' {'🎨'} 'nina' {'🧪'} 'charlotte' {'📡'} 'stella' {'🌌'}
      'jem' {'🐉'} 'carol' {'🔥'} 'abbey' {'🏦'} 'clarice' {'⚖️'} 'sorcha' {'🎬'} 'odessa' {'🏛️'}
      'themis' {'📜'} 'whitestar' {'⭐'} 'reyczar' {'👑'} default {'🏛️'}
    }
    $rel = '/'+($index.Replace($root,'').TrimStart('\','/').Replace('\','/'))
    $items += @{ id=$id; name=$name; icon=$icon; href=$rel }
  }
}

$doc = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; items=$items }
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($doc | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Wrote $OutFile with $($items.Count) entries."
