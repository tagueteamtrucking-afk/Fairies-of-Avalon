param(
  [string]$Model=$env:OPENAI_MODEL,
  [int]$Weeks=2,
  [int]$KcalA=1800,
  [int]$KcalB=1600,
  [string]$Pattern="DASH",
  [string]$Region="EU"
)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$apiKey=$env:OPENAI_API_KEY; if(-not $apiKey){ Write-Error "OPENAI_API_KEY missing"; exit 1 }
# Timeout selection: env OPENAI_TIMEOUT_SEC (default 300)
[int]$timeoutSec = 300
if ($env:OPENAI_TIMEOUT_SEC -and $env:OPENAI_TIMEOUT_SEC -match '^\d+$') { $timeoutSec = [int]$env:OPENAI_TIMEOUT_SEC }
$base = $env:OPENAI_PROXY_URL; if ([string]::IsNullOrWhiteSpace($base)) { $base = "https://api.openai.com" }
$chatUri = ($base.TrimEnd('/') + "/v1/chat/completions")
$expectedDays = [int]$Weeks * 7

$root=Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'pages/apps/carol/plans'; $null = New-Item -ItemType Directory -Path $outDir -Force
$ts=(Get-Date -Format "yyyyMMddTHHmmssZ")
$outFile = Join-Path $outDir ("twoperson-"+$Weeks+"wk-"+$ts+".json")

$prefsPath = Join-Path $root 'pages/apps/carol/profile/preferences.json'
$prefs = $null
if (Test-Path $prefsPath) { try { $prefs = Get-Content -Raw -Path $prefsPath | ConvertFrom-Json } catch {} }
$NameA = if ($prefs -and $prefs.names -and $prefs.names.A) { [string]$prefs.names.A } else { "Ray" }
$NameB = if ($prefs -and $prefs.names -and $prefs.names.B) { [string]$prefs.names.B } else { "Blanca" }

$sys = @"
You are CAROL, an evidence-first nutrition planner for TWO people for $Weeks week(s). Region=$Region (EFSA first, US NHLBI DGA fallback). Pattern=$Pattern.
Constraints (strict): snack-style plan (6–8 small events/day across A/B/Both), texture gentle (avoid very crunchy; light panko ok), shellfish-free; no cilantro; no cumin; light dairy (LF or plant-based); easy on onions & bell peppers. Truck-driver constraints: single burner + convection/microwave/airfryer; limited water/dishes; small fridge, slightly larger freezer; shopping every 14 days.
Budgets (soft): A=$KcalA kcal/day; B=$KcalB kcal/day. Sodium <=2000 mg/day (prefer 1500), added sugars <=10%% kcal, fiber >=25 g/day, sat fat <=10%% kcal.
Use standard cooking units only: cup, tbsp, tsp, g, kg, oz, piece, slice, can.
Return STRICT JSON only.
"@

$user = "Names: A=$NameA, B=$NameB. Provide 6–8 snack/mini-meal events per day. Include per-event nutrition and ingredients with units. Include 2-week shopping lists and minimal prep tasks."

$hdr = @{ "Authorization"="Bearer $apiKey"; "Content-Type"="application/json" }
$body = @{
  model=$Model; temperature=0.2; response_format=@{ type="json_object" }
  messages=@(@{role="system";content=$sys}, @{role="user";content=$user})
} | ConvertTo-Json -Depth 8

function Invoke-WithRetry {
  param([scriptblock]$Action, [int]$Max=6)
  $delay=2
  for($i=1;$i -le $Max;$i++){
    try{ return & $Action } catch {
      $msg = $_.Exception.Message
      if($i -eq $Max){ throw $_ }
      Write-Warning "Attempt $i failed: $msg — retrying in ${delay}s"
      Start-Sleep -Seconds $delay
      $delay = [Math]::Min(90, [int]([math]::Pow(2,$i)) )
    }
  }
}

try {
  $r = Invoke-WithRetry -Max 6 -Action { Invoke-RestMethod -Method Post -Uri $chatUri -Headers $hdr -Body $body -TimeoutSec $timeoutSec }
  $txt = $r.choices[0].message.content
  $j = $txt | ConvertFrom-Json
} catch {
  Write-Error "LLM/JSON error: $($_.Exception.Message)"
  exit 1
}

$j.updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
$j.region = $Region
$j.pattern = $Pattern
$j.weeks = $Weeks
$j.persons = @(@{id="A"; name=$NameA; kcal=$KcalA; events_per_day_target="6-8"}, @{id="B"; name=$NameB; kcal=$KcalB; events_per_day_target="6-8"})

# Ensure EXACT day count
$have = if ($j.days) { [int]$j.days.Count } else { 0 }
if ($have -lt $expectedDays) {
  Write-Warning "Plan returned $have days; expanding to $expectedDays by cycling."
  if (-not $j.days) { $j.days = @() }
  while ($j.days.Count -lt 7 -and $j.days.Count -gt 0) { $j.days += $j.days }
  $days = @()
  for($i=0;$i -lt $expectedDays;$i++){
    $clone = ($j.days[$i % $j.days.Count] | ConvertTo-Json -Depth 50 | ConvertFrom-Json)
    $clone.index = $i+1; $clone.day_label = "Day " + ($i+1)
    $days += $clone
  }
  $j.days = $days
} else {
  for($i=0;$i -lt $expectedDays;$i++){ if($i -lt $j.days.Count){ $j.days[$i].index=$i+1; if(-not $j.days[$i].day_label){ $j.days[$i].day_label="Day "+($i+1) } } }
}

[IO.File]::WriteAllText($outFile, ($j | ConvertTo-Json -Depth 50), [Text.Encoding]::UTF8)
Write-Host "Carol plan -> $outFile"
