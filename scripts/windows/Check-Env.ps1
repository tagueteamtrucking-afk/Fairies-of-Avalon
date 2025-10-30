# Check-Env.ps1 — Windows PowerShell 5.1+ or PowerShell 7+
$ErrorActionPreference = 'Stop'
Write-Host "=== Environment Check ==="
$node = (Get-Command node -ErrorAction SilentlyContinue)
if(-not $node){ throw "Node.js 18+ not found. Install from https://nodejs.org/" }
node -v
Write-Host "OK"
