param([string]$Model=$env:OPENAI_MODEL)
if([string]::IsNullOrWhiteSpace($Model)){$Model="gpt-4.1-mini"}
$api=$env:OPENAI_API_KEY; if(-not $api){Write-Error "OPENAI_API_KEY missing"; exit 1}
$root=Split-Path -Parent $PSScriptRoot; $outDir=Join-Path $root 'pages/apps/jem/programs'; New-Item -ItemType Directory -Path $outDir -Force|Out-Null
$out=Join-Path $outDir ("week1-evaluation-"+(Get-Date -Format "yyyyMMddTHHmmssZ")+".json")
$sys=@"
You are JEM. Create a Week‑1 Evaluation plan for two long‑haul truck drivers focusing on knee-friendly mobility and joint strengthening.
Include: baseline tests (30s sit-to-stand, 2‑min step test, comfortable walk duration, RPE explanations), daily low‑impact sessions, and a log template.
Return STRICT JSON: { updated, title, tests:[{name,how,targets,notes}], daily:[{day, focus, session:[string]}], log_template:[{field,example}], safety_notes }
"@
$user="Keep sessions <= 20 minutes; no door anchors; self-anchored bands only; add warm-up & cool-down; include off-day walking goals."
$hdr=@{"Authorization"="Bearer $api";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{$r=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body; $txt=$r.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $j=$txt|ConvertFrom-Json }catch{Write-Error "LLM/JSON error: $_"; exit 1}
$j.updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'
[IO.File]::WriteAllText($out,($j|ConvertTo-Json -Depth 16),[Text.Encoding]::UTF8); Write-Host "Week‑1 evaluation -> $out"
