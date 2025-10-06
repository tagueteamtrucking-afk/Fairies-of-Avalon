param([Parameter()][object]$PlansToGenerate=3,[Parameter()][string]$Model=$env:OPENAI_MODEL,[Parameter()][string]$ProjectTitle="Avalon Site v1")
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$count = As-Int -Value $PlansToGenerate
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Host "OPENAI_API_KEY not set. Skipping Carol LLM."; exit 0 }
$Root = Split-Path -Parent $PSScriptRoot
$plansPath = Join-Path (Join-Path $Root 'pages/apps/carol') 'plans'
$null = New-Item -ItemType Directory -Path $plansPath -Force
$prompt = "You are Carol, a planning agent. Output STRICT JSON only, no markdown. Schema: { plans: [{ id, title, tasks[] }] }. Generate "+$count+" concise execution plans to build and ship '"+$ProjectTitle+"'. Keep each plan under ~7 tasks. If a task needs prerequisites, note them."
$body = @{ model=$Model; messages=@(@{role="user";content=$prompt}); temperature=0.2 } | ConvertTo-Json -Depth 6
$headers = @{ "Authorization"="Bearer "+$apiKey; "Content-Type"="application/json" }
try { $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $text=$resp.choices[0].message.content; if($text -match '```'){ $text=($text -replace '```json','' -replace '```','').Trim() }; $obj=$text|ConvertFrom-Json } catch { Write-Error "Carol LLM failed: $_"; exit 1 }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$plansOut=@()
foreach($p in $obj.plans){ $slug = ($p.id -replace '[^a-zA-Z0-9\-]','-').ToLower(); $file = "plan-"+$slug+".json"
  [IO.File]::WriteAllText((Join-Path $plansPath $file), (@{ id=$p.id; title=$p.title; tasks=$p.tasks; created=$now; version="1.0.0" }|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
  $plansOut += @{ id=$p.id; title=$p.title; file=$file }
}
[IO.File]::WriteAllText((Join-Path $plansPath 'index.json'), (@{ updated=$now; plans=$plansOut }|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host ("Carol LLM: wrote {0} plans." -f $plansOut.Count)
