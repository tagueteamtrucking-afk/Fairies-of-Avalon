param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [string]$Voice = "en-US-JennyNeural",
  [string]$Format = "audio-24khz-48kbitrate-mono-mp3",
  [string]$Region = ""
)
$ErrorActionPreference='Stop'

$worldsRoot = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if([string]::IsNullOrWhiteSpace($World)){
  $latest = Join-Path $worldsRoot "latest.txt"
  if(!(Test-Path $latest)){ throw "No worlds yet. Run avalon-run-all first." }
  $World = Get-Content -LiteralPath $latest -TotalCount 1
}
$pipeDir = Join-Path $RepoRoot ('pages/apps/charlotte/pipelines/' + $World)
if(!(Test-Path $pipeDir)){ throw "Pipeline not found for world: $World" }
$planPath = Join-Path $pipeDir "plan.json"
if(!(Test-Path $planPath)){ throw "Missing plan.json at $planPath" }
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json

$outDir = Join-Path $RepoRoot ('pages/apps/charlotte/voiceovers/' + $World)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if([string]::IsNullOrWhiteSpace($env:AZURE_TTS_KEY) -or ([string]::IsNullOrWhiteSpace($Region) -and [string]::IsNullOrWhiteSpace($env:AZURE_TTS_REGION))){
  Write-Warning "No Azure TTS secrets/region. Writing text placeholders."
  foreach($t in $plan.tts_tasks){
    $txt = $t.ssml
    Set-Content -LiteralPath (Join-Path $outDir ($t.id + '.txt')) -Value $txt -Encoding UTF8
  }
  return
}

if([string]::IsNullOrWhiteSpace($Region)){ $Region = $env:AZURE_TTS_REGION }
$endpoint = "https://$Region.tts.speech.microsoft.com/cognitiveservices/v1"

foreach($t in $plan.tts_tasks){
  $ssml = $t.ssml
  try{
    Invoke-WebRequest -Uri $endpoint -Method Post -Headers @{
      "Ocp-Apim-Subscription-Key" = $env:AZURE_TTS_KEY
      "X-Microsoft-OutputFormat"  = $Format
      "User-Agent"                = "avalon-tts-cli"
    } -ContentType "application/ssml+xml" -Body $ssml -OutFile (Join-Path $outDir ($t.id + '.mp3')) -PassThru | Out-Null
  }catch{
    Write-Warning "TTS call failed: $($_.Exception.Message). Writing placeholder text."
    Set-Content -LiteralPath (Join-Path $outDir ($t.id + '.txt')) -Value $t.ssml -Encoding UTF8
  }
}
Write-Host "Voiceovers written to $outDir"
