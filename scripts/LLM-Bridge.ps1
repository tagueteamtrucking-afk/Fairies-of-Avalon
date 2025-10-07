
param([Parameter()][object]$WorldsToGenerate=3,[Parameter()][string]$Model=$env:OPENAI_MODEL)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$count = As-Int -Value $WorldsToGenerate
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Host "OPENAI_API_KEY not set. Skipping LLM Bridge."; exit 0 }
$Root = Split-Path -Parent $PSScriptRoot
$worldsPath = Join-Path (Join-Path $Root 'pages/apps/alexandria') 'worlds'
$null = New-Item -ItemType Directory -Path $worldsPath -Force
$messages = @(
  @{ role="system"; content="You are Alexandria, a worldbuilding agent. Output STRICT JSON only. Schema: { items: [{ id, slug, title, summary, lore, seedPrompts[] }] }" },
  @{ role="user"; content=("Create {0} imaginative worlds for a creative index." -f $count) }
)
$body = @{ model=$Model; messages=$messages; temperature=0.3 } | ConvertTo-Json -Depth 6
$headers = @{ "Authorization"="Bearer " + $apiKey; "Content-Type"="application/json" }
try { $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $text=$resp.choices[0].message.content; if($text -match '```'){ $text=($text -replace '```json','' -replace '```','').Trim() }; $obj=$text|ConvertFrom-Json } catch { Write-Error "LLM request or JSON parse failed: $_"; exit 1 }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$items=@()
foreach($w in $obj.items){ $slug = if($w.slug){$w.slug}else{ ($w.id -replace '[^a-zA-Z0-9\-]','-').ToLower() }; $file = "world-$slug.json"
  $worldOut = @{ id=$w.id; title=$w.title; lore=$w.lore; seedPrompts=$w.seedPrompts; created=$now; version="1.0.0" }
  [IO.File]::WriteAllText((Join-Path $worldsPath $file), ($worldOut|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
  $items += @{ id=$w.id; slug=$slug; title=$w.title; summary=$w.summary; file=$file }
}
[IO.File]::WriteAllText((Join-Path $worldsPath 'index.json'), (@{ updated=$now; items=$items }|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host ("LLM Bridge: wrote {0} worlds." -f $items.Count)
