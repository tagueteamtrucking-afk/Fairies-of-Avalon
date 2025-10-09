param([string]$Model = $env:OPENAI_MODEL,[string]$Goal="mobility",[string]$Experience="novice",[int]$WeeklySessions=5,[int]$MaxSessionMin=20)
if([string]::IsNullOrWhiteSpace($Model)){$Model="gpt-4.1-mini"}
$api=$env:OPENAI_API_KEY; if(-not $api){Write-Error "OPENAI_API_KEY missing"; exit 1}
$root=Split-Path -Parent $PSScriptRoot; $outDir=Join-Path $root 'pages/apps/jem/programs'; New-Item -ItemType Directory -Path $outDir -Force|Out-Null
$out=Join-Path $outDir ("program-"+(Get-Date -Format "yyyyMMddTHHmmssZ")+".json")
$evp=Join-Path $root 'pages/apps/jem/library/evidence.json'; $ev=@(); if(Test-Path $evp){try{$ev=(Get-Content -Raw $evp|ConvertFrom-Json).sources}catch{}}
$sys=@"
You are JEM, a fitness coach for long-haul truck drivers. Week-1 focus is knee-friendly mobility and joint strengthening.
No door anchors. Tools: bodyweight, loop bands self-anchored around feet/hands/torso, optional kettlebell <=16kg, step-ups (truck step only), loaded carries with water jugs. Space ~2.5 m^2.
Sessions <= $MaxSessionMin min. Weekly sessions=$WeeklySessions. Goal=$Goal. Experience=$Experience.
Use RPE/RIR; include warm-up and mobility. Provide regressions and progressions. If pain: substitute pattern and lower volume. Cite WHO/ACSM for general guidance.
Return STRICT JSON: { updated, profile:{goal,experience,tools,space}, week, sessions:[{id, day, duration_min, blocks:[{type, minutes, details, regressions, progressions}]}], evaluation:[{test,how,record}], safety_notes, sources }
"@
$user="Generate micro-sessions for cab/stop environments; add Week-1 evaluation tests (e.g., sit-to-stand in 30s, 2-min step test, comfortable walking duration), knee-friendly focus."
$hdr=@{"Authorization"="Bearer $api";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{$r=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body; $txt=$r.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $j=$txt|ConvertFrom-Json }catch{Write-Error "LLM/JSON error: $_"; exit 1}
$j.updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; if($ev){$j.sources=$ev}
[IO.File]::WriteAllText($out,($j|ConvertTo-Json -Depth 16),[Text.Encoding]::UTF8); Write-Host "Jem plan -> $out"
