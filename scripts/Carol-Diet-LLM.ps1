
param([string]$Model=$env:OPENAI_MODEL,[int]$Kcal=2200,[string]$Region="EU",[string]$Pattern="DASH",[string]$Context="truck_driver")
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey=$env:OPENAI_API_KEY; if(-not $apiKey){ Write-Error "OPENAI_API_KEY missing"; exit 1 }
$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/carol/plans'
$null = New-Item -ItemType Directory -Path $outDir -Force
$outFile = Join-Path $outDir ("mealplan-" + (Get-Date -Format "yyyyMMddTHHmmssZ") + ".json")

$evidencePath = Join-Path $Root 'pages/apps/carol/library/evidence.json'
$ev=@(); if(Test-Path $evidencePath){ try { $ev=(Get-Content -Raw -Path $evidencePath|ConvertFrom-Json).sources } catch{} }

$sys = @"
You are CAROL, an evidence-first nutrition planner (EU-first, US fallback).
Pattern=$Pattern, target kcal=$Kcal, region=$Region, context=$Context.
Rules: sodium <= 2000mg/day (pref 1500), added sugars <=10%% kcal, fiber >=25g/day, sat fat <=10%% kcal.
Provide 7-day menu with per-meal kcal/sodium/added sugars/fiber; include shelf-stable truck-friendly options.
Cite sources from the provided list; if uncertain, say so.
Output STRICT JSON: { updated, kcal, pattern, days: [{day, meals:[{name, kcal, sodium_mg, added_sugars_g, fiber_g, items:[string]}]}], shopping_list: [string], sources }
"@

$user = "Generate a 7-day plan meeting constraints."

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.25;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{ $resp=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $txt=$resp.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $json=$txt|ConvertFrom-Json } catch { Write-Error "LLM/JSON error: $_"; exit 1 }
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'; $json.updated=$now; if($ev){ $json.sources=$ev }
[IO.File]::WriteAllText($outFile, ($json|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
Write-Host "Carol plan -> $outFile"
