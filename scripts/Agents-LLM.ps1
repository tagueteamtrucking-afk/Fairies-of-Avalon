
param([Parameter(Mandatory)][string]$Agent,[Parameter()][string]$Model = $env:OPENAI_MODEL,[Parameter()][int]$Count = 3,[Parameter()][string]$Task = "produce structured JSON artifacts for this project")
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY; if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "OPENAI_API_KEY missing"; exit 1 }
function Slug([string]$n){ return ([regex]::Replace($n.ToLower(), "[^a-z0-9]+", "-")).Trim('-') }
$Root = Split-Path -Parent $PSScriptRoot
$slug = Slug $Agent
$base = Join-Path (Join-Path $Root 'pages/apps') $slug
$null = New-Item -ItemType Directory -Path $base -Force
$outPath = Join-Path $base 'index.json'
$sys = @"
You are $Agent, a specialized agent in the Avalon project.
Output STRICT JSON only, no markdown.
Schema: {"updated": iso8601, "agent": string, "items": [ { "id": string, "title": string, "summary": string, "data": object } ] }.
Refuse to guess; if uncertain, set 'summary' to explain uncertainty.
"@
$user = "Create $Count compact items to $Task. Each item under ~120 words."
$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
$body = @{ model=$Model; temperature=0.2; messages=@(@{role="system";content=$sys},@{role="user";content=$user}) } | ConvertTo-Json -Depth 6
try { $resp=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $text=$resp.choices[0].message.content; if($text -match '```'){ $text=($text -replace '```json','' -replace '```','').Trim() }; $json=$text|ConvertFrom-Json; $json.updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; [IO.File]::WriteAllText($outPath, ($json|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8); Write-Host "$Agent: wrote $outPath" } catch { Write-Error "$Agent failed: $($_.Exception.Message)"; exit 1 }
