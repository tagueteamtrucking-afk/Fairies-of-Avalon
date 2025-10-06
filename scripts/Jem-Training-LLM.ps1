param(
  [string]$Goal = "hypertrophy",
  [string]$Experience = "novice",
  [int]$WeeklySessions = 5,
  [string[]]$Equipment = @("bodyweight","resistance_bands","door_anchor","truck_step"),
  [string]$Context = "truck_driver",  # truck_driver | home | gym
  [int]$MaxSessionMin = 20,
  [string]$Model = $env:OPENAI_MODEL
)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY; if (-not $apiKey) { Write-Error "OPENAI_API_KEY missing"; exit 1 }

$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/jem/programs'
$null = New-Item -ItemType Directory -Path $outDir -Force

$sys = @"
You are JEM, an evidence-bound training assistant for long-haul truck drivers working in very small spaces.
Output STRICT JSON only.
Constraints:
- Environment: truck cab or immediate area around the truck; minimal space (<= 2.5 m^2); zero gym machines.
- Allowed equipment: bodyweight, resistance bands with door anchor, small suspension strap, truck step, optional single kettlebell (<= 16kg).
- Session design: micro-sessions <= {0} minutes; prefer 3-6 minute blocks (EMOM/AMRAP) distributed through the day at stops.
- Safety: no jumping inside the cab; avoid heavy fatigue right before long driving blocks; watch pain_gate <=3/10.
- Red flags or injuries -> advise clinician; do not prescribe treatment.
- Each plan MUST include sources[] with URLs from WHO/ACSM/NSCA/ISSN/NIH/NHLBI.
Schema:
{{ "id": string, "goal": string, "experience": string, "weekly_sessions": int, "equipment":[string],
  "screening": {{ "red_flags":[string], "pain_gate": {{"scale":"0-10","max_allowed":3}} }},
  "microcycles":[{{"week":int,"sessions":[{{"name":string,"blocks":[{{"minutes":int,"structure":"EMOM|AMRAP|TIMED","moves":[string]}}],
  "mobility":[string], "walk_min":int, "notes":string}}]}}],
  "progression":{{"rule": "Increase 2–10% volume or band tension after two sessions above target.", "deload":"every 4–6 weeks or high fatigue"}},
  "recovery":{{"sleep_h":7.5,"steps_min":6000,"mobility_min":10}},
  "nutrition_hooks":{{"protein_g_per_kg":1.6,"kcal_bias":"maintenance","handoff_to":"carol_li"}},
  "sources":[{{"label":string,"url":string,"quality":"guideline|position-stand"}}]
}}
"@ -f $MaxSessionMin

$user = @{
  goal=$Goal; experience=$Experience; weekly_sessions=$WeeklySessions;
  equipment=$Equipment; context=$Context; max_session_min=$MaxSessionMin
} | ConvertTo-Json -Depth 6

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body = @{ model=$Model; temperature=0.15; messages=@(@{role="system";content=$sys},@{role="user";content=("Create a conservative program with these inputs:\n"+$user)}) } | ConvertTo-Json -Depth 8

try {
  $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
  $txt = $resp.choices[0].message.content
  if($txt -match '```'){ $txt = ($txt -replace '```json','' -replace '```','').Trim() }
  $obj = $txt | ConvertFrom-Json
  $id = if ($obj.id) { $obj.id } else { "program-"+([Guid]::NewGuid().ToString("N").Substring(0,8)) }
  $out = Join-Path $outDir ($id + ".json")
  [IO.File]::WriteAllText($out, ($obj|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
  Write-Host "Jem: wrote $out"
} catch { Write-Error "Jem generation failed: $($_.Exception.Message)"; exit 1 }
