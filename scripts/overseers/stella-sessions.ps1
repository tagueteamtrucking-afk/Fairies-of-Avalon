[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
$outDir = Join-Path $RepoRoot "pages/apps/stella"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$sessions = @(
  @{ title='Breath & Orbit'; script='Breathe in 4, hold 4, out 6. Imagine orbiting the Avalon star…' },
  @{ title='Focus Bell'; script='Three tones. With each tone, your attention returns to one calm point.' }
)
($sessions | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "sessions.json") -Encoding utf8NoBOM
Write-Host "Sessions written."
exit 0
