param([string]$WorldName="Avalon",[string]$Tone="high fantasy",[string]$MagicStyle="semi-hard, cost-based",[string]$Model=$env:OPENAI_MODEL)
if([string]::IsNullOrWhiteSpace($Model)){$Model="gpt-4.1-mini"}
$api=$env:OPENAI_API_KEY; if(-not $api){Write-Error "OPENAI_API_KEY missing"; exit 1}
$root=Split-Path -Parent $PSScriptRoot; $base=Join-Path $root 'pages/apps/alexandria/worlds'; New-Item -ItemType Directory -Path $base -Force|Out-Null
function Slug($s){ return ($s -replace '[^a-zA-Z0-9\- ]','' -replace '\s+','-').ToLower() }
$slug = Slug $WorldName; $dir=Join-Path $base $slug; New-Item -ItemType Directory -Path $dir -Force|Out-Null
$out=Join-Path $dir 'world.json'
$sys=@"
You are ALEXANDRIA, a worldbuilding DM partner. Build a concise 'world bible' skeleton for a tabletop campaign.
Include: premise, themes, geography (regions & landmarks), cultures & societies, magic rules ({$MagicStyle}), technology, factions, economy, pantheon, bestiary seeds, quest hooks, session zero boundaries & safety tools, dice prompts.
Output STRICT JSON:
{ world: { name, tone, premise, themes:[string], geography:{regions:[{name,notes}], landmarks:[{name,notes}]}, cultures:[{name,traits}], magic:{sources, costs, limits}, technology:{level,notes}, factions:[{name,agenda,assets}], economy:{currencies,trade}, pantheon:[{name,domain}], bestiary:[{name,role}], hooks:[string], safety_tools:[string], dice_prompts:[string] } }
"@
$user="World name: $WorldName. Tone: $Tone. Keep it tight but gameable."
$hdr=@{"Authorization"="Bearer $api";"Content-Type"="application/json"}
$body=@{model=$Model;temperature=0.35;messages=@(@{role="system";content=$sys},@{role="user";content=$user})}|ConvertTo-Json -Depth 6
try{$r=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $hdr -Body $body; $txt=$r.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $j=$txt|ConvertFrom-Json }catch{Write-Error "LLM/JSON error: $_"; exit 1}
[IO.File]::WriteAllText($out,($j|ConvertTo-Json -Depth 16),[Text.Encoding]::UTF8); Write-Host "World bible -> $out"
