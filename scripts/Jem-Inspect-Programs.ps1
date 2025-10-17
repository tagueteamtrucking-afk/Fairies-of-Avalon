param(
  [string]$ProgramsDir="pages/apps/jem/programs"
)
$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root $ProgramsDir
if(-not (Test-Path $dir)){ Write-Error "ProgramsDir not found: $dir"; exit 1 }
$files = Get-ChildItem -Path $dir -Filter "*.json" -File -ErrorAction SilentlyContinue
Write-Host "== Programs listing =="
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
    $pname = $null
    if($j.person){
      if($j.person -is [string]){ $pname = $j.person }
      elseif($j.person.PSObject.Properties.Name -contains 'name'){ $pname = $j.person.name }
    } elseif($j.PSObject.Properties.Name -contains 'name'){ $pname = $j.name }
    Write-Host ("{0,-34}  person: {1}" -f $f.Name, ($pname ?? '<none>'))
  }catch{
    Write-Host ("{0,-34}  <invalid JSON>" -f $f.Name)
  }
}
