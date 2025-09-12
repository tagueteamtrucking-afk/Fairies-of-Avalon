# Ray Czar — Overseer Engineer & Builder
# Purpose: quick queue/status snapshot for Actions logs + JSON report.

[CmdletBinding()]
param(
  [ValidateSet('list','all')]
  [string]$Action = 'list'
)

$ErrorActionPreference = 'Stop'

$Root   = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Queue  = Join-Path $Root 'apps\overseers\queue'
$OutDir = (Resolve-Path "$PSScriptRoot\..\out" -ErrorAction SilentlyContinue).Path
New-Item -ItemType Directory -Force -Path $Queue  | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$items = Get-ChildItem -Path $Queue -Filter *.json -File -Force | Sort-Object Name
$report = [ordered]@{
  ts    = (Get-Date).ToString('s') + 'Z'
  actor = 'ray-czar'
  count = $items.Count
  items = $items | ForEach-Object { $_.Name }
}

$path = Join-Path $OutDir 'ray-czar.queue.json'
$report | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $path
Write-Host ("Queue items: {0}" -f $items.Count)
$items | ForEach-Object { Write-Host " - $_" }
exit 0
