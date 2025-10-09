param(
  [string]$Model=$env:OPENAI_MODEL,
  [int]$Weeks=2,
  [int]$KcalA=1800,
  [int]$KcalB=1600,
  [string]$Pattern="DASH",
  [string]$Region="EU"
)
# TLS
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$apiKey=$env:OPENAI_API_KEY; if(-not $apiKey){ Write-Error "OPENAI_API_KEY missing"; exit 1 }
$base = $env:OPENAI_PROXY_URL; if ([string]::IsNullOrWhiteSpace($base)) { $base = "https://api.openai.com" }
$chatUri = ($base.TrimEnd('/') + "/v1/chat/completions")
$expectedDays = [int]$Weeks * 7

$root=Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'pages/apps/carol/plans'; $null = New-Item -ItemType Directory -Path $outDir -Force
$ts=(Get-Date -Format "yyyyMMddTHHmmssZ")
$outFile = Join-Path $outDir ("twoperson-"+$Weeks+"wk-"+$ts+".json")

$prefsPath = Join-Path $root 'pages/apps/carol/profile/preferences.json'
$feedbackPath = Join-Path $root 'pages/apps/carol/profile/feedback.json'
$prefs = $null; $feedback=$null
if (Test-Path $prefsPath) { try { $prefs = Get-Content -Raw -Path $prefsPath | ConvertFrom-Json } catch {} }
if (Test-Path $feedbackPath) { try { $feedback = Get-Content -Raw -Path $feedbackPath | ConvertFrom-Json } catch {} }

$peanut = "no whole peanuts; powder or peanut butter only"
$texture = "avoid very crunchy foods; light panko coating OK; favor tender textures"
$appliances = if ($prefs -and $prefs.appliances) { ($prefs.appliances -join ", ") } else { "single burner, convection/microwave/airfryer, small processor, immersion blender, stand mixer, crock-pot" }
$intDays  = if ($prefs -and $prefs.shopping_interval_days) { [string]$prefs.shopping_interval_days } else { "14" }
$storage  = "fridge is smaller-than-standard; freezer slightly larger; shopping interval "+$intDays+" days"
$prep     = "bulk prep not required; partial prep/components OK"
$grazing  = "Grazers: plan 6–8 snack-size eating events per person per day (not 3 meals); allow asynchronous schedules."
$avoid    = "Exclusions: no shellfish; no cilantro; no cumin; easy on onions and bell peppers (use milder forms/amounts)."
$dairy    = "Light dairy restriction: likely lactose intolerance — prefer lactose-free milk/yogurt, low-lactose aged cheeses, and plant-based alternatives; annotate substitutions in item notes."

$learn = ""
if ($feedback) {
  $likes = ($feedback.likes -join ", ")
  $dislikes = ($feedback.dislikes -join ", ")
  $avoid_more = ($feedback.avoid -join ", ")
  $notes = ($feedback.notes -join "; ")
  $learn = "Learning from feedback — Likes: "+$likes+"; Dislikes: "+$dislikes+"; Extra avoid: "+$avoid_more+"; Notes: "+$notes+"."
}

$sys = @"
You are CAROL, an evidence-first nutrition planner for TWO people and for $Weeks week(s).
Pattern=$Pattern. Region=$Region (EU-first safety; US fallback). Person A daily kcal=$KcalA; Person B daily kcal=$KcalB.
Context:
- Texture: $texture; $peanut.
- Appliances: $appliances.
- Storage: $storage.
- $prep.
- Truck-driver constraints: minimal dishes, limited space, limited water.
- $grazing
- $avoid
- $dairy
$learn
Weight status: both are 40+ lbs overweight. Favor moderate energy deficit, high-satiety meals (protein + fiber), lower energy density, freezer-friendly components.
Safety & guidance: follow EFSA first (EU), then NHLBI DASH / DGA (US) as fallback. Sodium <= 2000 mg/day (prefer 1500), added sugars <= 10% kcal, fiber >= 25 g/day, sat fat <= 10% kcal.

FORMAT & QUANTITY RULES (STRICT):
- Produce EXACTLY $expectedDays day objects in `days` with indices 1..$expectedDays. If uncertain, extend by cycling variations to fill all days.
- Each day must contain a total of 6–8 events across Both/A/B combined. Use `for:"A"|"B"|"Both"`.
- Use STANDARD COOKING UNITS in items: unit ∈ {"cup","tbsp","tsp","g","kg","oz","piece","slice","can"}; prefer cup/tbsp/tsp for volumes.
- Include per-event nutrition: kcal, sodium_mg, added_sugars_g, fiber_g.
- Include clear ingredients with quantities and units, and concise notes; if dairy present, note the lactose-free or plant-based substitution in `notes`.
Return STRICT JSON:
{
  updated, region, pattern, weeks,
  persons:[{id,name,kcal, events_per_day_target:"6-8"}],
  days:[{ index, day_label,
          events:[{ name, for:"A|B|Both", type:"snack|mini-meal", time_hint, kcal, sodium_mg, added_sugars_g, fiber_g,
                    items:[{ingredient, quantity, unit, notes}]}] }],
  shopping_lists_2wk:[{ range:"wk1-2|wk3-4|wk5-6",
                         produce:[string], protein:[string], dairy:[string], pantry:[string], frozen:[string], spices:[string] }],
  component_prep:[{ when:"Day 1|Day 8|Each Week", tasks:[string] }],
  storage_notes:[string],
  sources
}
"@

$user = "Names: A=Ray, B=Blanca. Keep prep short. Use slow-cooker & convection oven. Provide swaps for cilantro/cumin and lactose-light alternatives."

$hdr = @{ "Authorization"="Bearer $apiKey"; "Content-Type"="application/json" }
$body = @{ model=$Model; temperature=0.2; messages=@(@{role="system";content=$sys}, @{role="user";content=$user}) } | ConvertTo-Json -Depth 8

function Invoke-WithRetry {
  param([scriptblock]$Action, [int]$Max=6)
  $delay=2
  for($i=1;$i -le $Max;$i++){
    try{
      return & $Action
    } catch {
      $msg = $_.Exception.Message
      if($i -eq $Max){ throw $_ }
      Write-Warning "Attempt $i failed: $msg — retrying in ${delay}s"
      Start-Sleep -Seconds $delay
      $delay = [Math]::Min(60, [int]([math]::Pow(2,$i)) )
    }
  }
}

# Call chat with retries
try {
  $r = Invoke-WithRetry -Max 6 -Action { Invoke-RestMethod -Method Post -Uri $chatUri -Headers $hdr -Body $body -TimeoutSec 120 }
  $txt = $r.choices[0].message.content
  if ($txt -match '```') { $txt = ($txt -replace '```json','' -replace '```','').Trim() }
  $j = $txt | ConvertFrom-Json
} catch {
  Write-Error "LLM/JSON error: $($_.Exception.Message)"
  exit 1
}

# Fill metadata
$NameA = "Ray"; $NameB = "Blanca"
try {
  if ($prefs -and $prefs.names) { if($prefs.names.A){ $NameA = [string]$prefs.names.A }; if($prefs.names.B){ $NameB = [string]$prefs.names.B } }
} catch {}

$j.updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
$j.region = $Region
$j.pattern = $Pattern
$j.weeks = $Weeks
$j.persons = @(@{id="A"; name=$NameA; kcal=$KcalA; events_per_day_target="6-8"}, @{id="B"; name=$NameB; kcal=$KcalB; events_per_day_target="6-8"})

# Normalize days to expected length
try {
  $have = if ($j.days) { [int]$j.days.Count } else { 0 }
  if ($have -lt $expectedDays) {
    Write-Warning "Plan returned $have days; expanding to $expectedDays by cycling."
    $base = @()
    if ($j.days) { $base = $j.days }
    if ($base.Count -eq 0) { throw "No days returned by LLM" }
    while ($base.Count -lt 7) { $base += $base } # ensure enough variety to cycle
    $days = @()
    for ($i=0; $i -lt $expectedDays; $i++) {
      $clone = ($base[$i % $base.Count] | ConvertTo-Json -Depth 32 | ConvertFrom-Json)
      $clone.index = $i + 1
      $clone.day_label = "Day " + ($i + 1)
      $days += $clone
    }
    $j.days = $days
  } else {
    for ($i=0; $i -lt $expectedDays; $i++) {
      if ($i -lt $j.days.Count) {
        $j.days[$i].index = $i + 1
        if (-not $j.days[$i].day_label) { $j.days[$i].day_label = "Day " + ($i + 1) }
      }
    }
  }
} catch {
  Write-Warning "Could not normalize days: $_"
}

[IO.File]::WriteAllText($outFile, ($j | ConvertTo-Json -Depth 32), [Text.Encoding]::UTF8)
Write-Host "Carol plan -> $outFile"
