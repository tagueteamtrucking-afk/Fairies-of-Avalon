
param([Parameter()][string]$Model = $env:OPENAI_MODEL,[Parameter()][string]$Voice = "alloy",[Parameter()][string]$Format = "mp3")
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4o-mini-tts" }
$apiKey = $env:OPENAI_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) { Write-Error "OPENAI_API_KEY missing"; exit 1 }
$Root = Split-Path -Parent $PSScriptRoot
$apps = Join-Path $Root 'pages/apps/charlotte'
$pipeIndex = Join-Path $apps 'pipelines/index.json'
$voiceDir  = Join-Path $apps 'voiceovers'
$voiceIndex = Join-Path $voiceDir 'index.json'
$null = New-Item -ItemType Directory -Path $voiceDir -Force
if (-not (Test-Path $pipeIndex)) {
  $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  $obj = @{ updated = $now; pipelines = @(@{ id="welcome"; text="Welcome to Avalon. Build the AI and let them build the site." }) }
  [IO.File]::WriteAllText($pipeIndex, ($obj|ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
}
$pipes = Get-Content -Raw -Path $pipeIndex | ConvertFrom-Json
$entries = @()
$headers=@{ "Authorization"="Bearer $apiKey"; "Content-Type"="application/json" }
foreach ($p in $pipes.pipelines) {
  $text = $p.text; $file = Join-Path $voiceDir ($p.id + "." + $Format)
  $body = @{ model=$Model; input=$text; voice=$Voice; format=$Format } | ConvertTo-Json -Depth 6
  try {
    Invoke-WebRequest -Method Post -Uri "https://api.openai.com/v1/audio/speech" -Headers $headers -Body $body -OutFile $file | Out-Null
    $entries += @{ id=$p.id; file=("voiceovers/" + (Split-Path -Leaf $file)); model=$Model; voice=$Voice }
    Write-Host "Synthesized: $($p.id)"
  } catch { Write-Warning "OpenAI TTS failed for $($p.id): $($_.Exception.Message)" }
}
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$idx = @{ updated=$now; items=$entries }
[IO.File]::WriteAllText($voiceIndex, ($idx|ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Charlotte TTS (OpenAI): updated."
