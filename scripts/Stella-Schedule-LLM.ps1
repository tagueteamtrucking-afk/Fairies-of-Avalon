
param(
  [Parameter()][string]$Model = $env:OPENAI_MODEL,
  [Parameter()][string]$PersonaA = "Ray",
  [Parameter()][string]$PersonaB = "Blanca",
  [Parameter()][string]$Timezone = "America/Chicago"
)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "OPENAI_API_KEY missing"; exit 1 }

$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $Root 'pages/apps/stella'
$null = New-Item -ItemType Directory -Path $outDir -Force
$outFile = Join-Path $outDir 'schedule.json'

$evidencePath = Join-Path $Root 'pages/apps/stella/library/evidence.json'
$evidence = @()
if (Test-Path $evidencePath) { try { $evidence = (Get-Content -Raw -Path $evidencePath | ConvertFrom-Json).sources } catch {} }

$sys = @"
You are STELLA, a supportive, non-clinical sound companion rooted in:
- basic NLP framing (positive, actionable prompts),
- meditation and mindfulness best practices (NCCIH summaries),
- hypnosis safety overview (APA) without making clinical claims,
- general sound therapy principles (non-medical).

Always include short safety notes (not medical advice).
Output STRICT JSON only with this schema:
{
 "updated": iso8601,
 "timezone": string,
 "personas": [
   {
     "name": string,
     "profile": { "goals":[string], "sensitivities":[string] },
     "day_plan": [
       { "start": "HH:MM", "end": "HH:MM", "mood_goal": string, "sound": { "type": string, "bpm": string, "notes": string }, "nlp_prompt": string }
     ]
   }
 ],
 "sources": [ { "label": string, "url": string } ]
}
Constraints:
- Keep total plan compact: ~6–10 blocks per persona per day (wake → sleep).
- Use 'type' like: pink/brown noise, binaural-like (non-medical), ambient pads, nature, lo-fi, silence interval.
- Use clear, supportive language; avoid clinical claims.
"@

$user = @"
Create a day-long plan for two personas:
- Persona A: {0}
- Persona B: {1}
Timezone: {2}
Include 2–3 focus blocks (work/drive), 1–2 relaxation blocks, and a wind-down/sleep block.
"@ -f $PersonaA, $PersonaB, $Timezone

$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body = @{ model=$Model; temperature=0.35; messages=@(@{role="system";content=$sys},@{role="user";content=$user}) } | ConvertTo-Json -Depth 6
try {
  $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
  $txt  = $resp.choices[0].message.content
  if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }
  $json = $txt | ConvertFrom-Json
} catch {
  Write-Error "LLM or JSON parse failed: $($_.Exception.Message)"; exit 1
}

$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'
$json.updated = $now
if ($null -ne $evidence -and $evidence.Count -gt 0) { $json.sources = $evidence }

[IO.File]::WriteAllText($outFile, ($json|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
Write-Host "Stella schedule written: $outFile"
