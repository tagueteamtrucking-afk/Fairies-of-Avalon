param([string]$Persona="Ray",[string]$Theme="calm",[int]$DurationMin=10,[string]$Model=$env:OPENAI_MODEL)
if([string]::IsNullOrWhiteSpace($Model)){$Model="gpt-4.1-mini"}
$api=$env:OPENAI_API_KEY; if(-not $api){Write-Error "OPENAI_API_KEY missing"; exit 1}
$root=Split-Path -Parent $PSScriptRoot; $base=Join-Path $root 'pages/apps/stella/guided'; New-Item -ItemType Directory -Path $base -Force|Out-Null
$slug=(Get-Date -Format 'yyyyMMddTHHmmssZ')+"-"+($Persona.ToLower().Replace(' ','-'))+"-"+$Theme
$outDir=Join-Path $base $slug; New-Item -ItemType Directory -Path $outDir -Force|Out-Null
$scriptFile=Join-Path $outDir 'script.json'; $audioFile=Join-Path $outDir 'audio.mp3'
$sys=@"
You are STELLA, a supportive non-clinical guide for on-demand meditation/hypnosis-style sessions.
Output a safe, inclusive, gentle script tailored for $Persona with theme '$Theme' and duration ~ $DurationMin minutes.
Avoid medical claims; include brief safety note at the end.
Return STRICT JSON: { title, persona, theme, steps:[{t_sec, text}], safety_note }
"@
$user="Create the script with calm pacing; ~100-130 wpm; break into 20-40 sec steps."
$hdr=@{"Authorization"="Bearer $api";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.35;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{$r=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body; $txt=$r.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $j=$txt|ConvertFrom-Json }catch{Write-Error "LLM/JSON error: $_"; exit 1}
[IO.File]::WriteAllText($scriptFile,($j|ConvertTo-Json -Depth 8),[Text.Encoding]::UTF8)
try{
  $ttsBody=@{ model="gpt-4o-mini-tts"; input=($j.steps|ForEach-Object{$_.text}) -join " "; voice="alloy"; format="mp3" } | ConvertTo-Json -Depth 6
  Invoke-WebRequest -Method Post -Uri "https://api.openai.com/v1/audio/speech" -Headers @{"Authorization"="Bearer $api";"Content-Type"="application/json"} -Body $ttsBody -OutFile $audioFile | Out-Null
}catch{ Write-Warning "TTS failed: $($_.Exception.Message)" }
Write-Host "Stella guided -> $outDir"
