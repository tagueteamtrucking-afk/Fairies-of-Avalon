param(
  [Parameter()][string]$Voice = "en-US-AriaNeural",
  [Parameter()][string]$Format = "riff-16khz-16bit-mono-pcm"
)
$region = $env:AZURE_TTS_REGION
$key    = $env:AZURE_TTS_KEY
if ([string]::IsNullOrWhiteSpace($region) -or [string]::IsNullOrWhiteSpace($key)) { Write-Host "Azure TTS secrets not set. Skipping."; exit 0 }
$Root = Split-Path -Parent $PSScriptRoot
$apps = Join-Path $Root 'pages/apps/charlotte'
$pipeIndex = Join-Path $apps 'pipelines/index.json'
$voiceDir  = Join-Path $apps 'voiceovers'
$voiceIndex = Join-Path $voiceDir 'index.json'
$null = New-Item -ItemType Directory -Path $voiceDir -Force
if (-not (Test-Path $pipeIndex)) {
  Write-Host "No pipelines found at $pipeIndex; creating default welcome pipeline."
  $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  $obj = @{ updated = $now; pipelines = @(@{ id="welcome"; text="Welcome to Avalon. Build the AI and let them build the site."; voice=$Voice; format=$Format }) }
  [IO.File]::WriteAllText($pipeIndex, ($obj | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
}
$pipes = Get-Content -Raw -Path $pipeIndex | ConvertFrom-Json
$entries = @()
foreach ($p in $pipes.pipelines) {
  $text = $p.text
  $v = if ($p.voice) { $p.voice } else { $Voice }
  $fmt = if ($p.format) { $p.format } else { $Format }
  $file = Join-Path $voiceDir ($p.id + ".wav")
  $ssml = @"
<speak version='1.0' xml:lang='en-US'>
  <voice name='$v'>$text</voice>
</speak>
"@
  $uri = "https://$region.tts.speech.microsoft.com/cognitiveservices/v1"
  $headers = @{
    "Ocp-Apim-Subscription-Key" = $key
    "Content-Type" = "application/ssml+xml"
    "X-Microsoft-OutputFormat" = $fmt
    "User-Agent" = "AvalonCharlotte"
  }
  try {
    Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $ssml -OutFile $file
    $entries += @{ id = $p.id; file = "voiceovers/" + (Split-Path -Leaf $file); voice = $v }
    Write-Host "Synthesized: $($p.id)"
  } catch { Write-Warning "TTS failed for $($p.id): $_" }
}
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$idx = @{ updated = $now; items = $entries }
[IO.File]::WriteAllText($voiceIndex, ($idx | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Charlotte TTS: updated voiceovers index."
