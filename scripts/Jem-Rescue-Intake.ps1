param(
  [string]$ImportsDir="pages/apps/jem/imports",
  [string]$IntakeDir="pages/apps/jem/intake"
)
$root = Split-Path -Parent $PSScriptRoot
$impAbs = Join-Path $root $ImportsDir
$intAbs = Join-Path $root $IntakeDir
if(-not (Test-Path $impAbs)){ Write-Error "Imports dir not found: $impAbs"; exit 1 }
New-Item -ItemType Directory -Force -Path $intAbs | Out-Null

$files = Get-ChildItem -Path $impAbs -Recurse -File | Where-Object { $_.Name -match "(?i)intake.*\.json$" -or $_.Name -match "(?i)(Ray|Blanca)-intake.*\.json$" }
if(-not $files){ Write-Warning "No intake*.json found under $ImportsDir"; exit 0 }

$seen=@{}
foreach($f in $files){
  $name = $f.Name -replace '\s+\(\d+\)',''  # drop (1) etc
  if($name -match '(?i)ray'){ $dest = Join-Path $intAbs 'Ray-intake.json' }
  elseif($name -match '(?i)blanca'){ $dest = Join-Path $intAbs 'Blanca-intake.json' }
  elseif($name -match '(?i)intake-both'){ $dest = Join-Path $intAbs 'intake-both.json' }
  else { $dest = Join-Path $intAbs $name }
  Write-Host "Moving $($f.FullName) -> $dest"
  Move-Item -Path $f.FullName -Destination $dest -Force
  $seen[[IO.Path]::GetFileName($dest)] = $true
}

# If individual files exist but both.json missing, compose it
$ray = Join-Path $intAbs 'Ray-intake.json'
$bla = Join-Path $intAbs 'Blanca-intake.json'
$both = Join-Path $intAbs 'intake-both.json'
if((Test-Path $ray) -and (Test-Path $bla) -and -not (Test-Path $both)){
  try{
    $r = Get-Content -Raw -Path $ray | ConvertFrom-Json
    $b = Get-Content -Raw -Path $bla | ConvertFrom-Json
    $out = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; persons=@($r,$b) }
    [IO.File]::WriteAllText($both, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
    Write-Host "Created intake-both.json"
  }catch{ Write-Warning "Failed to compose intake-both.json: $($_.Exception.Message)" }
}
Write-Host "Rescue complete."
