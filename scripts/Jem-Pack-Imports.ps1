param(
  [string]$ImportsDir="pages/apps/jem/imports",
  [string]$ZipName="SamsungHealthExport_Ray.zip"
)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$impAbs = Join-Path $root $ImportsDir
if(-not (Test-Path $impAbs)){ Write-Error "Imports dir not found: $impAbs"; exit 1 }

$zipPath = Join-Path $impAbs $ZipName
if(Test-Path $zipPath){ Remove-Item -Force $zipPath }

# Include any Samsung Health files and CSVs that look like exports
$files = Get-ChildItem -Path $impAbs -Recurse -File | Where-Object { $_.Name -match '^com\.samsung\.health\..*' -or $_.Extension -match '^\.(csv|json)$' }
if(-not $files){ Write-Error "No Samsung Health source files under $ImportsDir to pack."; exit 1 }

# Create a temp staging folder that mirrors a typical export root
$tmp = Join-Path $env:RUNNER_TEMP ("shealth_pack_"+([guid]::NewGuid()))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
foreach($f in $files){
  Copy-Item -Path $f.FullName -Destination (Join-Path $tmp $f.Name) -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $zipPath)
Write-Host "Created $zipPath"
