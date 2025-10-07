
$Root = Split-Path -Parent $PSScriptRoot
$file = Join-Path $Root 'pages/apps/stella/schedule.json'
if (-not (Test-Path $file)) { Write-Error "schedule.json not found"; exit 1 }
try { $j = Get-Content -Raw -Path $file | ConvertFrom-Json } catch { Write-Error "Parse failed"; exit 1 }
if (-not $j.personas -or $j.personas.Count -lt 1) { Write-Error "Missing personas"; exit 1 }
foreach($p in $j.personas){
  if (-not $p.day_plan -or $p.day_plan.Count -lt 3) { Write-Error "Day plan too short for $($p.name)"; exit 1 }
}
Write-Host "Stella validate OK."
