param([Parameter()][string]$Model = $env:OPENAI_MODEL,[Parameter()][object]$Temperature = 0.1)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1') -ErrorAction SilentlyContinue | Out-Null
try{ $temp = As-Int -Value $Temperature }catch{ $temp = 0 }
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = "gpt-4.1-mini" }
$apiKey = $env:OPENAI_API_KEY
$Root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path (Join-Path $Root 'pages/diagnostics') 'factcheck'
$null = New-Item -ItemType Directory -Path $outDir -Force
if ([string]::IsNullOrWhiteSpace($apiKey)) {
  $now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
  [IO.File]::WriteAllText((Join-Path $outDir 'index.json'), (@{ updated=$now; status="skipped"; reason="missing OPENAI_API_KEY" }|ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
  exit 0
}
function Read-Json($p){ if (Test-Path $p){ try { Get-Content -Raw -Path $p | ConvertFrom-Json } catch { $null } } else { $null } }
$targets = @(
  @{ name="carol"; path="pages/apps/carol/plans/index.json"; key="plans" },
  @{ name="jem"; path="pages/apps/jem/programs/index.json"; key="programs" },
  @{ name="stella"; path="pages/apps/stella/components/index.json"; key="items" },
  @{ name="alexandria"; path="pages/apps/alexandria/worlds/index.json"; key="items" }
)
$headers=@{ "Authorization"="Bearer $apiKey"; "Content-Type"="application/json" }
function Check-List($Agent,$Items){
  $checked=@(); $issues=@()
  foreach($it in $Items){
    $snippet = $it | ConvertTo-Json -Depth 6
    $sys = "You are a rigorous fact-checker and schema validator for "+$Agent+". Output strict JSON: {""ok"":bool,""needs_source"":bool,""fiction"":bool,""missing"":[string],""notes"":string}."
    $body = @{ model=$Model; temperature=$temp; messages=@(@{role="system";content=$sys},@{role="user";content=("Check this JSON:\n"+$snippet)}) } | ConvertTo-Json -Depth 6
    try { $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body; $txt=$resp.choices[0].message.content; if($txt -match '```'){ $txt=($txt -replace '```json','' -replace '```','').Trim() }; $obj=$txt|ConvertFrom-Json; if($null -eq $obj){ $issues += @{id=$it.id; error="json-parse-failed"; raw=$txt} } else { $checked += @{ id=$it.id; result=$obj } } } catch { $issues += @{ id=$it.id; error="request-failed"; detail=$_.Exception.Message } }
  }
  return @{ checked=$checked; issues=$issues }
}
$results=@()
foreach($t in $targets){
  $idx = Read-Json (Join-Path (Split-Path -Parent $PSScriptRoot) $t.path.Replace('/', [IO.Path]::DirectorySeparatorChar))
  if ($null -eq $idx) { $results += @{ agent=$t.name; status="missing-index"; path=$t.path }; continue }
  $items=@()
  foreach($i in $idx.$($t.key)){ if ($i.file){ $p = Join-Path ((Split-Path -Parent (Join-Path (Split-Path -Parent $PSScriptRoot) $t.path))) $i.file; $j=Read-Json $p; if($j){ $items += $j } } }
  $res = Check-List $t.name $items
  $results += @{ agent=$t.name; counts=@{ items=$items.Count; checked=$res.checked.Count; issues=$res.issues.Count }; details=$res }
}
$now=(Get-Date).ToUniversalTime().ToString("s")+"Z"
[IO.File]::WriteAllText((Join-Path $outDir 'index.json'), (@{ updated=$now; model=$Model; temperature=$temp; results=$results }|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host "Fact-check complete."
