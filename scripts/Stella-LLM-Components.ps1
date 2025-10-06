param([Parameter()][object]$ComponentsToGenerate=5,[Parameter()][string]$Model=$env:OPENAI_MODEL,[Parameter()][string]$Theme="treasure-map")
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$count = As-Int -Value $ComponentsToGenerate
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4o-mini" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Host "OPENAI_API_KEY not set. Skipping Stella LLM."; exit 0 }

$Root = Split-Path -Parent $PSScriptRoot
$compPath = Join-Path (Join-Path $Root 'pages/apps/stella') 'components'
$null = New-Item -ItemType Directory -Path $compPath -Force

$prompt = @"
You are Stella, a UI component architect. Output STRICT JSON only, no markdown.
Schema: { components: [{ id, slug, title, summary, blueprint: { html, css, js } }] }.
Design $count components that fit a '$Theme' theme (e.g., treasure-map CTAs, parchment cards, path dividers).
Keep HTML/CSS minimal and self-contained (no external frameworks). Avoid backticks.
"@
$body = @{ model=$Model; messages=@(@{role="user";content=$prompt}); temperature=0.5 } | ConvertTo-Json -Depth 6
$headers = @{ "Authorization"="Bearer "+$apiKey; "Content-Type"="application/json" }
try { $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $text=$resp.choices[0].message.content; if($text -match '```'){ $text=($text -replace '```json','' -replace '```','').Trim() }; $obj=$text|ConvertFrom-Json } catch { Write-Error "Stella LLM failed: $_"; exit 1 }

$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$items=@()
foreach($c in $obj.components){
  $slug = if($c.slug){$c.slug}else{ ($c.id -replace '[^a-zA-Z0-9\-]','-').ToLower() }
  $file = "component-"+$slug+".json"
  $out = @{ id=$c.id; title=$c.title; summary=$c.summary; blueprint=$c.blueprint; created=$now; version="1.0.0" }
  [IO.File]::WriteAllText((Join-Path $compPath $file), ($out|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
  $items += @{ id=$c.id; slug=$slug; title=$c.title; summary=$c.summary; file=$file }
}
[IO.File]::WriteAllText((Join-Path $compPath 'index.json'), (@{ updated=$now; items=$items }|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host ("Stella LLM: wrote {0} components." -f $items.Count)
