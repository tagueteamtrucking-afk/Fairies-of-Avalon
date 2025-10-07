
param([int]$Worlds = 1,[string]$Model = $env:OPENAI_MODEL)
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1" }
$apiKey = $env:OPENAI_API_KEY; if (-not $apiKey) { Write-Error "OPENAI_API_KEY missing"; exit 1 }
$Root = Split-Path -Parent $PSScriptRoot
$dmDir = Join-Path $Root 'pages/apps/alexandria/dm'
$null = New-Item -ItemType Directory -Path $dmDir -Force
$sys = @"
You are ALEXANDRIA, a Dungeon Master AI for collaborative storytelling.
Output STRICT JSON only.
For each world, produce a compact DM pack with this schema:
{
 "world": {"id": string, "title": string, "genre": string, "tone": string,
           "pillars": ["exploration","social","combat"],
           "magic": {"sources":[string],"costs":[string],"limits":[string],"schools":[string]},
           "pantheon":[{"name":string,"domain":string,"taboos":[string]}],
           "cultures":[{"name":string,"values":[string],"tech_level":string}],
           "factions":[{"name":string,"goal":string,"assets":[string]}],
           "geography":{"regions":[{"name":string,"traits":[string]}]},
           "laws":{"taboos":[string],"punishments":[string]}
 },
 "random_tables": {
   "hooks":[{"d":20,"rows":[string]}],
   "npcs":[{"d":20,"rows":[string]}],
   "local_events":[{"d":12,"rows":[string]}]
 },
 "session_seeds": [{"title":string,"setup":string,"twist":string}],
 "house_rules": [{"name":string,"effect":string}],
 "novelization": {"serial_title":string,"season_outline":[{"ep":int,"beat":string}]}
}
"@
$user = "Create {0} DM packs. Keep each field compact but evocative." -f $Worlds
$body = @{ model=$Model; temperature=0.35; messages=@(@{role="system";content=$sys},@{role="user";content=$user}) } | ConvertTo-Json -Depth 6
$headers=@{"Authorization"="Bearer $apiKey";"Content-Type"="application/json"}
try {
  $resp=Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
  $txt=$resp.choices[0].message.content
  if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }
  $obj=$txt|ConvertFrom-Json
} catch { Write-Error "Alexandria DM failed: $($_.Exception.Message)"; exit 1 }
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'
$index = @{ updated=$now; worlds=@() }
$wcount = 0
foreach($pack in $obj){
  $id = if ($pack.world.id){ $pack.world.id } else { "dm-"+([Guid]::NewGuid().ToString("N").Substring(0,8)) }
  $file = "$id.json"
  [IO.File]::WriteAllText((Join-Path $dmDir $file), ($pack|ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
  $index.worlds += @{ id=$id; title=$pack.world.title; file=$file }
  $wcount++
}
[IO.File]::WriteAllText((Join-Path $dmDir 'index.json'), ($index|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host "Alexandria DM: wrote $wcount packs."
