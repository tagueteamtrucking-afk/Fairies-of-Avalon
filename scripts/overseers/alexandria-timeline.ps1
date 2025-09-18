param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World,
  [int]$Count = 7
)
$ErrorActionPreference='Stop'
$worldsDir = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if(!(Test-Path $worldsDir)){ throw "No worlds dir: $worldsDir" }

function EnsureWorld([string]$Dir,[string]$W){
  if([string]::IsNullOrWhiteSpace($W)){
    $latest = Get-ChildItem -LiteralPath $Dir -Filter 'seed-*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if(!$latest){ throw "No seeds directory found: $Dir" }
    return ($latest.BaseName.Substring(5))
  }
  return $W
}
$World = EnsureWorld $worldsDir $World

$acts = @("Act I","Act II","Act III")
$events = @()
for($i=1;$i -le [Math]::Max(1,$Count);$i++){
  $events += [ordered]@{
    idx = $i
    title = "Event $i"
    when  = ("Year " + (100+$i))
    location = if($i%2 -eq 0) { "Capital" } else { "Frontier" }
    tags = @("main","arc"+$i)
    summary = "Pivotal moment $i sets the stage."
  }
}
$out = [ordered]@{ world=$World; structure=$acts; events=$events }
$outPath = Join-Path $worldsDir ("timeline-" + $World + ".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Wrote $outPath"
