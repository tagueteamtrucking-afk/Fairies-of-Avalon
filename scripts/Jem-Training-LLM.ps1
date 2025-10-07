
param([string]$Model = $env:OPENAI_MODEL,[string]$Goal = "hypertrophy",[string]$Experience="novice",[int]$WeeklySessions=5,[string]$Context="truck_driver",[int]$MaxSessionMin=20)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY; if (-not $apiKey) { Write-Error "OPENAI_API_KEY missing"; exit 1 }
$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/jem/programs'
$null = New-Item -ItemType Directory -Path $outDir -Force
$outFile = Join-Path $outDir ("program-" + (Get-Date -Format "yyyyMMddTHHmmssZ") + ".json")

$evidencePath = Join-Path $Root 'pages/apps/jem/library/evidence.json'
$ev = @(); if (Test-Path $evidencePath){ try { $ev = (Get-Content -Raw -Path $evidencePath | ConvertFrom-Json).sources } catch {} }

$sys = @"
You are JEM, a fitness coach for truck drivers with limited space/equipment.
Constraints: 2.5 m^2 space, bodyweight/bands/door-anchor/truck-step, optional KB<=16kg; sessions <= $MaxSessionMin min.
Use RPE and RIR; scale to $Experience; goal=$Goal; $WeeklySessions sessions/week.
ALWAYS cite sources from the provided list when making claims; if uncertain, say so.
Output STRICT JSON: { updated, profile, week, sessions: [{id, day, duration_min, blocks: [{type, minutes, details}]}], safety_notes, sources }
"@

$user = "Generate a one-week plan with micro-sessions, context="+$Context

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{ $resp=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $txt=$resp.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $json=$txt|ConvertFrom-Json } catch { Write-Error "LLM/JSON error: $_"; exit 1 }
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'; $json.updated=$now; if($ev){ $json.sources=$ev }
[IO.File]::WriteAllText($outFile, ($json|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
Write-Host "Jem plan -> $outFile"
