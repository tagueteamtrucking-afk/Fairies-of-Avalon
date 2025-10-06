param([Parameter()][string]$Voice = "en-US-AriaNeural",[Parameter()][string]$Format = "riff-16khz-16bit-mono-pcm")
$region = $env:AZURE_TTS_REGION; $key = $env:AZURE_TTS_KEY
if ([string]::IsNullOrWhiteSpace($region) -or [string]::IsNullOrWhiteSpace($key)) { Write-Host "Azure TTS secrets not set. Skipping."; exit 0 }
$Root = Split-Path -Parent $PSScriptRoot
$apps = Join-Path $Root 'pages/apps/charlotte'
$pipeIndex = Join-Path $apps 'pipelines/index.json'
$voiceDir  = Join-Path $apps 'voiceovers'
$voiceIndex = Join-Path $voiceDir 'index.json'
$null = New-Item -ItemType Directory -Path $voiceDir -Force
if (-not (Test-Path $pipeIndex)) {
  $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  $obj = @{ updated=$now; pipelines=@(@{ id="welcome"; text="Welcome to Avalon." }) }
  [IO.File]::WriteAllText($pipeIndex, ($obj | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
}
$pipes = Get-Content -Raw -Path $pipeIndex | ConvertFrom-Json
$entries=@()
foreach ($p in $pipes.pipelines) {
  $text=$p.text; $file = Join-Path $voiceDir ($p.id + ".wav")
  $ssml = "<speak version='1.0' xml:lang='en-US'><voice name='"+$Voice+"'>"+$text+"</voice></speak>"
  $uri = "https://$region.tts.speech.microsoft.com/cognitiveservices/v1"
  $headers = @{ "Ocp-Apim-Subscription-Key"=$key; "Content-Type"="application/ssml+xml"; "X-Microsoft-OutputFormat"=$Format; "User-Agent"="AvalonCharlotte" }
  try { Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $ssml -OutFile $file; $entries += @{ id=$p.id; file=("voiceovers/"+(Split-Path -Leaf $file)); voice=$Voice } } catch { Write-Warning "Azure TTS failed: $($_.Exception.Message)" }
}
$now=(Get-Date).ToUniversalTime().ToString("s")+"Z"
[IO.File]::WriteAllText($voiceIndex, (@{ updated=$now; items=$entries }|ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Charlotte TTS (Azure): updated."
