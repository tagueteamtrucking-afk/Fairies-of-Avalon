param(
  [string]$Model=$env:OPENAI_MODEL,
  [int]$Weeks=2,                    # 2 or 6
  [int]$KcalA=2200,
  [int]$KcalB=2000,
  [string]$Pattern="DASH",
  [string]$Region="EU"
)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$api=$env:OPENAI_API_KEY; if(-not $api){ Write-Error "OPENAI_API_KEY missing"; exit 1 }
$root=Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'pages/apps/carol/plans'; $null = New-Item -ItemType Directory -Path $outDir -Force
$ts=(Get-Date -Format "yyyyMMddTHHmmssZ")
$outFile = Join-Path $outDir ("twoperson-"+$Weeks+"wk-"+$ts+".json")

$prefsPath = Join-Path $root 'pages/apps/carol/profile/preferences.json'
$prefs = $null
if (Test-Path $prefsPath) { try { $prefs = Get-Content -Raw -Path $prefsPath | ConvertFrom-Json } catch {} }

$peanut = "no whole peanuts; powder or peanut butter only"
$texture = "avoid very crunchy foods; light panko coating OK; favor tender textures"
$appliances = ($prefs.appliances -join ", ")
$storage = "fridge is smaller-than-standard; freezer slightly larger; shopping interval "+($prefs.shopping_interval_days|Out-String).Trim()+" days"
$prep = "bulk prep not required; partial prep/components OK"

$sys = @"
You are CAROL, an evidence-first nutrition planner for TWO people and for $Weeks week(s).
Pattern=$Pattern. Region=$Region (EU-first safety; US fallback). Person A daily kcal=$KcalA; Person B daily kcal=$KcalB.
Context:
- Texture: $texture; $peanut.
- Appliances available: $appliances.
- Storage: $storage.
- $prep.
- Truck-driver constraints: minimal dishes, limited space, limited water.
Safety & guidance: follow EFSA first (EU), then NHLBI DASH / DGA (US) as fallback. Sodium target <= 2000 mg/day (prefer 1500), added sugars <=10% kcal, fiber >= 25 g/day, sat fat <=10% kcal.
Deliver:
- A $Weeks-week menu for two people with per-meal kcal/sodium/added_sugars/fiber and specific quantities.
- A two-week shopping list grouped by aisle (produce, protein, dairy, pantry, frozen, spices). If Weeks=6, provide three 2‑week lists (wk1–2, 3–4, 5–6).
- A component prep plan (moist-heat / slow-cooker friendly; note freezer vs fridge items).
- Prefer softer textures (braise, stew, sauce, casseroles, slow-cooker, minced or shredded proteins); allow light panko oven-baked chicken; avoid hard-crisp coatings and whole crunchy nuts.
Return STRICT JSON:
{
  updated, region, pattern, weeks, persons:[{id,name,kcal}],
  days:[{index, day_label, meals:[{name, for:"A|B|Both", kcal, sodium_mg, added_sugars_g, fiber_g, items:[{ingredient, quantity, unit, notes}]}]}],
  shopping_lists_2wk:[{range:"wk1-2|wk3-4|wk5-6", produce:[string], protein:[string], dairy:[string], pantry:[string], frozen:[string], spices:[string]}],
  component_prep:[{when:"Day 1|Day 8|Each Week", tasks:[string]}],
  storage_notes:[string],
  sources
}
"@

$user = "Names: A=Ray, B=Blanca. Keep recipes short. Minimize pots. Use slow-cooker and convection oven often. Include optional swaps for texture sensitivity."

$hdr = @{ "Authorization"="Bearer $api"; "Content-Type"="application/json" }
$body = @{ model=$Model; temperature=0.25; messages=@(@{role="system";content=$sys}, @{role="user";content=$user}) } | ConvertTo-Json -Depth 8

try {
  $r = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body
  $txt = $r.choices[0].message.content
  if ($txt -match '```') { $txt = ($txt -replace '```json','' -replace '```','').Trim() }
  $j = $txt | ConvertFrom-Json
} catch {
  Write-Error "LLM/JSON error: $_"
  exit 1
}

$j.updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
$j.region = $Region
$j.pattern = $Pattern
$j.weeks = $Weeks
$j.persons = @(@{id="A"; name=($prefs.names.A ?: "Ray"); kcal=$KcalA}, @{id="B"; name=($prefs.names.B ?: "Blanca"); kcal=$KcalB})
[IO.File]::WriteAllText($outFile, ($j | ConvertTo-Json -Depth 32), [Text.Encoding]::UTF8)

Write-Host "Carol plan -> $outFile"
