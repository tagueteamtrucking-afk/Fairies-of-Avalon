# Rey Czar — Overseer Engineer & Builder
# Purpose: queue/status snapshot for Actions logs + JSON report (non-failing).
# Usage in Actions:
#   pwsh -File "apps/overseers/ai/rey-czar.ps1" -Action list

[CmdletBinding()]
param(
  [ValidateSet('list','all')]
  [string]$Action = 'list'
)

$ErrorActionPreference = 'Stop'

function Get-ProjectRoot {
  # ai/ -> overseers/ -> apps/ -> repo root
  return (Resolve-Path "$PSScriptRoot\..\..\..").Path
}

try {
  $Root   = Get-ProjectRoot
  $Queue  = Join-Path $Root 'apps\overseers\queue'
  $OutDir = Join-Path $Root 'apps\overseers\out'

  New-Item -ItemType Directory -Force -Path $Queue  | Out-Null
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

  $items = Get-ChildItem -Path $Queue -Filter *.json -File -Force -ErrorAction SilentlyContinue | Sort-Object Name

  $report = [ordered]@{
    ts    = (Get-Date).ToString('s') + 'Z'
    actor = 'rey-czar'
    count = $items.Count
    items = $items | ForEach-Object { $_.Name }
  }

  $path = Join-Path $OutDir 'rey-czar.queue.json'
  $report | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $path

  Write-Host ("Queue items: {0}" -f $items.Count)
  $items | ForEach-Object { Write-Host " - $_" }

  exit 0
}
catch {
  Write-Error ("Rey Czar error: {0}" -f ($_ | Out-String))
  exit 0   # non-fatal; don't break the workflow on status view
}
