param(
  [string]$ImportsDir="pages/apps/jem/imports",
  [string]$Output="pages/apps/jem/programs/biometrics.json"
)
$root = Split-Path -Parent $PSScriptRoot
$impAbs = Join-Path $root $ImportsDir
$outAbs = Join-Path $root $Output
if(-not (Test-Path $impAbs)){ Write-Error "Imports dir not found: $impAbs"; exit 1 }
$zips = Get-ChildItem -Path $impAbs -Filter "*.zip" -File -ErrorAction SilentlyContinue
if(-not $zips){ Write-Error "No Samsung Health export zips in $impAbs"; exit 1 }
$temp = Join-Path $env:RUNNER_TEMP "shealth_"+([guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temp | Out-Null

$summary = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; persons=@() }

Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach($z in $zips){
  [System.IO.Compression.ZipFile]::ExtractToDirectory($z.FullName, $temp, $true)
  # naive parse: find any CSV with 'step' in name, sum a recent window
  $csvs = Get-ChildItem -Path $temp -Recurse -Filter "*.csv" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "step" }
  $steps = 0
  foreach($c in $csvs){
    try{
      $t = Get-Content -Path $c.FullName | Select-Object -Skip 1
      foreach($line in $t){
        $parts = $line -split ","
        foreach($p in $parts){
          if($p -match "^\d{4,}$"){ $steps += [int]$p; break }
        }
      }
    } catch {}
  }
  $nameGuess = if($z.BaseName -match "Ray"){"Ray"} elseif($z.BaseName -match "Blanca"){"Blanca"} else {$z.BaseName}
  $summary.persons += @{ name=$nameGuess; steps_window=$steps }
}
$dirOut = Split-Path -Parent (Join-Path $root $Output)
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText((Join-Path $root $Output), ($summary | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Biometrics summary -> $Output"
