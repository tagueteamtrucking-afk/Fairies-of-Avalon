$root=Split-Path -Parent $PSScriptRoot
$src=Join-Path $root "Cody's Memory.yaml"
if (-not (Test-Path $src)) { Write-Host "No memory file found."; exit 0 }
$dstDir=Join-Path $root "memory-history"; New-Item -ItemType Directory -Path $dstDir -Force|Out-Null
$ts=Get-Date -Format "yyyyMMddTHHmmssZ"
Copy-Item $src (Join-Path $dstDir "$ts-Codys-Memory.yaml") -Force
Write-Host "Snapshot saved."
