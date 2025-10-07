param([string]$Model=$env:OPENAI_MODEL,[int]$KcalA=2200,[int]$KcalB=2000,[string]$Pattern="DASH",[string]$Region="EU")
if([string]::IsNullOrWhiteSpace($Model)){$Model="gpt-4.1-mini"}
$api=$env:OPENAI_API_KEY; if(-not $api){Write-Error "OPENAI_API_KEY missing"; exit 1}
$root=Split-Path -Parent $PSScriptRoot; $outDir=Join-Path $root 'pages/apps/carol/plans'; New-Item -ItemType Directory -Path $outDir -Force|Out-Null
$out=Join-Path $outDir ("twoperson-2wk-"+(Get-Date -Format "yyyyMMddTHHmmssZ")+".json")
$evp=Join-Path $root 'pages/apps/carol/library/evidence.json'; $ev=@(); if(Test-Path $evp){try{$ev=(Get-Content -Raw $evp|ConvertFrom-Json).sources}catch{}}
$sys=@"
You are CAROL, an evidence-first nutrition planner for TWO people and TWO weeks.
Pattern=$Pattern. Region=$Region (EU-first safety; US fallback). Person A daily kcal=$KcalA; Person B daily kcal=$KcalB.
Rules: sodium <= 2000mg/day (pref 1500), added sugars <=10%% kcal, fiber >=25g/day, sat fat <=10%% kcal.
Deliver:
- A 14-day menu for two people with per-meal kcal/sodium/added_sugars/fiber.
- A combined two-week shopping list grouped by section (produce, protein, dairy, pantry, frozen, spices).
- A batch-cook & storage plan (what to prep on Day 1/Day 8; fridge/freezer notes).
- Truck-friendly options (shelf-stable, minimal equipment).
Cite EFSA/NHLBI/DGA as appropriate.
Output STRICT JSON:
{ updated, region, pattern, persons:[{id,name,kcal}], days:[{day, meals:[{name, for:"A|B|Both", kcal, sodium_mg, added_sugars_g, fiber_g, items:[string], prep:[string]}]}], shopping_list:{produce:[string],protein:[string],dairy:[string],pantry:[string],frozen:[string],spices:[string]}, batch_cook:[{day, tasks:[string]}], sources }
"@
$user="Names: A=Ray, B=Blanca. Keep recipes short; specify quantities; mark 'Both' where same meal fits both."
$hdr=@{"Authorization"="Bearer $api";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{$r=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body; $txt=$r.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $j=$txt|ConvertFrom-Json }catch{Write-Error "LLM/JSON error: $_"; exit 1}
$j.updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; $j.region=$Region; $j.pattern=$Pattern; $j.persons=@(@{id="A";name="Ray";kcal=$KcalA},@{id="B";name="Blanca";kcal=$KcalB}); if($ev){$j.sources=$ev}
[IO.File]::WriteAllText($out,($j|ConvertTo-Json -Depth 16),[Text.Encoding]::UTF8); Write-Host "Carol plan -> $out"
