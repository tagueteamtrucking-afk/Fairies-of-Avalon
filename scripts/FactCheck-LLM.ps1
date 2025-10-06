param(
  [Parameter()][string]$Model = $env:OPENAI_MODEL,
  [Parameter()][object]$Temperature = 0.1
)
# Multi-agent fact-checker for Carol/Jem/Stella/Alexandria outputs
# - Reads JSON in pages/apps/** and writes diagnostics to pages/diagnostics/factcheck/**
# - Never throws on missing files; always returns 0 so workflows don't fail the build.
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1') -ErrorAction SilentlyContinue | Out-Null
try{ $temp = As-Int -Value $Temperature }catch{ $temp = 0 }

if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  Write-Warning "OPENAI_API_KEY not set; skipping LLM-based fact-check. Writing empty report."
  $Root = Split-Path -Parent $PSScriptRoot
  $outDir = Join-Path (Join-Path $Root 'pages/diagnostics') 'factcheck'
  $null = New-Item -ItemType Directory -Path $outDir -Force
  $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  $obj = @{ updated=$now; status="skipped"; reason="missing OPENAI_API_KEY" }
  [IO.File]::WriteAllText((Join-Path $outDir 'index.json'), ($obj|ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
  exit 0
}

$Root = Split-Path -Parent $PSScriptRoot
$apps = Join-Path $Root 'pages/apps'
$outDir = Join-Path (Join-Path $Root 'pages/diagnostics') 'factcheck'
$null = New-Item -ItemType Directory -Path $outDir -Force

function Read-JsonSafe {
  param([string]$Path)
  if (Test-Path $Path) {
    try { return Get-Content -Raw -Path $Path | ConvertFrom-Json } catch { return $null }
  }
  return $null
}

$targets = @(
  @{ name="carol";    path=(Join-Path $apps 'carol/plans/index.json');       key="plans"     },
  @{ name="jem";      path=(Join-Path $apps 'jem/programs/index.json');      key="programs"  },
  @{ name="stella";   path=(Join-Path $apps 'stella/components/index.json'); key="items"     },
  @{ name="alexandria"; path=(Join-Path $apps 'alexandria/worlds/index.json'); key="items"   }
)

$headers = @{ "Authorization"="Bearer $apiKey"; "Content-Type"="application/json" }
function Check-Items {
  param([string]$Agent,[array]$Items,[string]$Key)
  $issues = @()
  $checked = @()
  foreach($it in $Items){
    # Build a concise JSON to pass to the checker
    $snippet = $it | ConvertTo-Json -Depth 6
    $sys = @"
You are a rigorous fact-checker and schema validator for $Agent outputs.
Rules:
- Do NOT invent or assume facts beyond the snippet.
- If a sentence asserts real-world facts (dates, stats, legal/medical claims), mark `needs_source=true`.
- If content is creative (fictional world details), mark `fiction=true` and `needs_source=false`.
- Validate structure for required fields. List missing fields in `missing`.
- Output STRICT JSON only: {{"ok": bool, "needs_source": bool, "fiction": bool, "missing": [string], "notes": string}}
"@
    $user = "Check this JSON snippet:\n"+$snippet
    $body = @{ model=$Model; temperature=$temp; messages=@(@{role="system";content=$sys},@{role="user";content=$user}) } | ConvertTo-Json -Depth 6
    try {
      $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
      $txt = $resp.choices[0].message.content
      if ($txt -match '```') { $txt = ($txt -replace '```json','' -replace '```','').Trim() }
      $obj = $txt | ConvertFrom-Json
      if ($null -eq $obj) { $issues += @{ id=$it.id; error="json-parse-failed"; raw=$txt } }
      else { $checked += @{ id=$it.id; result=$obj } }
    } catch {
      $issues += @{ id=$it.id; error="request-failed"; detail=$_.Exception.Message }
    }
  }
  return @{ checked=$checked; issues=$issues }
}

$results = @()
foreach($t in $targets){
  $idx = Read-JsonSafe -Path $t.path
  if ($null -eq $idx) { $results += @{ agent=$t.name; status="missing-index"; path=$t.path } ; continue }
  $items = @()
  foreach($i in $idx.$($t.key)){
    if ($i.file) {
      $p = Join-Path (Split-Path -Parent $t.path) $i.file
      $j = Read-JsonSafe -Path $p
      if ($j) { $items += $j }
    }
  }
  $res = Check-Items -Agent $t.name -Items $items -Key $t.key
  $results += @{ agent=$t.name; path=$t.path; counts=@{ items=$items.Count; checked=$res.checked.Count; issues=$res.issues.Count }; details=$res }
}

$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$summary = @{ updated=$now; model=$Model; temperature=$temp; results=$results }
[IO.File]::WriteAllText((Join-Path $outDir 'index.json'), ($summary | ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host "Fact-check complete."
exit 0
