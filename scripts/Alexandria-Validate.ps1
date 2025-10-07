
$Root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $Root 'pages/apps/alexandria/dm'
if (-not (Test-Path $dir)){ Write-Host "No Alexandria DM packs."; exit 0 }
$bad=@()
Get-ChildItem -File $dir -Filter *.json | Where-Object { $_.Name -ne 'index.json' } | ForEach-Object {
  try {
    $j = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json
    if (-not $j.world -or -not $j.random_tables -or -not $j.session_seeds) { $bad += @{file=$_.Name; issue="missing-keys"} }
    elseif (-not $j.world.magic -or -not $j.world.factions) { $bad += @{file=$_.Name; issue="missing-magic-or-factions"} }
  } catch { $bad += @{file=$_.Name; issue="parse-failed"} }
}
if ($bad.Count -gt 0) { Write-Error ("Alexandria validate failed: " + ($bad | ConvertTo-Json -Depth 6)); exit 1 }
Write-Host "Alexandria DM validate OK."
