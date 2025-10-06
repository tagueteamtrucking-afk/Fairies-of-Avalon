param(
  [string]$Pattern = "DASH",
  [int]$Kcal = 2200,
  [string[]]$Allergies = @(),
  [string[]]$Preferences = @("omnivore"),
  [string]$Region = "EU",
  [string]$Context = "truck_driver",   # truck_driver | home | office
  [string]$Model = $env:OPENAI_MODEL
)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY; if (-not $apiKey) { Write-Error "OPENAI_API_KEY missing"; exit 1 }

$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/carol/plans'
$null = New-Item -ItemType Directory -Path $outDir -Force

$sys = @"
You are CAROL, an evidence-bound nutrition assistant for long-haul truck drivers.
Output STRICT JSON only.
Constraints:
- Storage: small cooler/mini-fridge; prefer shelf-stable and ready-to-eat items.
- Prep: microwave or electric kettle; minimal chopping; avoid strong odors.
- Safety: EU-first (EFSA); US (DGA/NHLBI/AHA) fallback. No medical claims.
- Defaults: sodium <= 2000 mg/day (DASH alt 1500), added sugars <= 10% kcal, fiber >= 25 g/day, sat fat <= 10% kcal.
- Each plan MUST include sources[] with EFSA/NHLBI/DGA/AHA/WHO links.
Schema:
{ "id": "plan-<slug>","pattern": "DASH|Low_Sodium|Low_Sugar",
  "kcal_target": int,
  "macro_targets": {"protein_g_per_kg": number, "fat_%kcal": number, "carb_%kcal": number},
  "daily_limits": {"sodium_mg":{"target":2000,"alt_dash_low":1500},"added_sugars_%kcal":10,"fiber_g":25,"sat_fat_%kcal":10},
  "days":[{"day":1,"menus":[{"meal":"Breakfast","items":["Greek yogurt","banana","oats"],"est_kcal":450,"sodium_mg":220,"added_sugars_g":6,"fiber_g":8}]}],
  "shopping_list": ["shelf-stable tuna pouches","low-sodium wholegrain crackers","fruit","UHT milk","instant oats","microwaveable brown rice","unsalted nuts"],
  "prep_tools": ["microwave","electric kettle","plastic knife","storage containers"],
  "compliance":{"eu_ok":true,"us_ok":true,"notes":"EU sodium AI 2000 mg; DASH patterns; sugars <10% kcal; fiber >=25 g"},
  "sources":[{"label":"EFSA DRV sodium","url":"https://efsa.onlinelibrary.wiley.com/doi/10.2903/j.efsa.2019.5778","quality":"DRV"}]
}
"@

$user = @{
  pattern=$Pattern; kcal_target=$Kcal; allergies=$Allergies; prefs=$Preferences; region=$Region; context=$Context
} | ConvertTo-Json -Depth 6

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body = @{ model=$Model; temperature=0.15; messages=@(@{role="system";content=$sys},@{role="user";content=("Create a 7-day truck-driver-friendly plan with per-meal numbers and shelf-stable shopping list:\n"+$user)}) } | ConvertTo-Json -Depth 8

try {
  $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
  $txt = $resp.choices[0].message.content
  if($txt -match '```'){ $txt = ($txt -replace '```json','' -replace '```','').Trim() }
  $obj = $txt | ConvertFrom-Json
  $id = if ($obj.id) { $obj.id } else { "plan-"+([Guid]::NewGuid().ToString("N").Substring(0,8)) }
  $out = Join-Path $outDir ($id + ".json")
  [IO.File]::WriteAllText($out, ($obj|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
  Write-Host "Carol: wrote $out"
} catch { Write-Error "Carol generation failed: $($_.Exception.Message)"; exit 1 }
