param([Parameter()][object]$ProgramsToGenerate=2,[Parameter()][string]$Model=$env:OPENAI_MODEL,[Parameter()][string]$Target="site-automation")
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$count = As-Int -Value $ProgramsToGenerate
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Host "OPENAI_API_KEY not set. Skipping Jem LLM."; exit 0 }
$Root = Split-Path -Parent $PSScriptRoot
$progPath = Join-Path (Join-Path $Root 'pages/apps/jem') 'programs'
$null = New-Item -ItemType Directory -Path $progPath -Force
$prompt = "You are Jem, a program-smith. Output STRICT JSON only, no markdown. Schema: { programs: [{ id, title, type, steps: [{name, action, params}] }] }. Create "+$count+" compact programs that help automate '"+$Target+"'. Avoid shell-specific syntax; just high-level actions and params."
$body = @{ model=$Model; messages=@(@{role="user";content=$prompt}); temperature=0.2 } | ConvertTo-Json -Depth 6
$headers = @{ "Authorization"="Bearer "+$apiKey; "Content-Type"="application/json" }
try { $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $text=$resp.choices[0].message.content; if($text -match '```'){ $text=($text -replace '```json','' -replace '```','').Trim() }; $obj=$text|ConvertFrom-Json } catch { Write-Error "Jem LLM failed: $_"; exit 1 }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$progsOut=@()
foreach($p in $obj.programs){ $slug = ($p.id -replace '[^a-zA-Z0-9\-]','-').ToLower(); $file = "program-"+$slug+".json"
  [IO.File]::WriteAllText((Join-Path $progPath $file), (@{ id=$p.id; title=$p.title; type=$p.type; steps=$p.steps; created=$now; version="1.0.0" }|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
  $progsOut += @{ id=$p.id; title=$p.title; type=$p.type; file=$file }
}
[IO.File]::WriteAllText((Join-Path $progPath 'index.json'), (@{ updated=$now; programs=$progsOut }|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host ("Jem LLM: wrote {0} programs." -f $progsOut.Count)
