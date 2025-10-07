
param([string]$Model = $env:OPENAI_MODEL,[string]$Goal = "hypertrophy",[string]$Experience="novice",[int]$WeeklySessions=5,[int]$MaxSessionMin=20)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$apiKey = $env:OPENAI_API_KEY; if (-not $apiKey) { Write-Error "OPENAI_API_KEY missing"; exit 1 }
$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/jem/programs'
$null = New-Item -ItemType Directory -Path $outDir -Force
$outFile = Join-Path $outDir ("program-" + (Get-Date -Format "yyyyMMddTHHmmssZ") + ".json")

$evPath = Join-Path $Root 'pages/apps/jem/library/evidence.json'
$ev=@(); if(Test-Path $evPath){ try { $ev=(Get-Content -Raw -Path $evPath|ConvertFrom-Json).sources } catch{} }

$sys = @"
You are JEM, a fitness coach for long-haul truck drivers. NO door anchors. Allowed tools: bodyweight, loop bands self-anchored around hands/feet/torso, an optional kettlebell <=16kg, truck step (only for step-ups), and common objects (water jugs) for loaded carries.
Space: ~2.5 m^2. Session cap: $MaxSessionMin min. Weekly sessions: $WeeklySessions. Goal=$Goal. Experience=$Experience.
Use RPE and RIR for progression. Include warm-up and at least one mobility block.
If pain is reported, substitute a pain-free pattern and reduce volume.
ALWAYS provide references from WHO/ACSM if giving general guidance.
Output STRICT JSON: { updated, profile:{goal,experience,tools,space}, week, sessions:[{id, day, duration_min, blocks:[{type, minutes, details, regressions, progressions}]}], safety_notes, sources }
"@

$user = "Generate one-week micro-sessions under constraints; avoid door-anchored rows/presses; propose self-anchored band options and bodyweight variations only."

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{ $resp=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $txt=$resp.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $json=$txt|ConvertFrom-Json } catch { Write-Error "LLM/JSON error: $_"; exit 1 }
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'; $json.updated=$now; if($ev){ $json.sources=$ev }
[IO.File]::WriteAllText($outFile, ($json|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
Write-Host "Jem plan -> $outFile"
