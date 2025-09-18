param([Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$World)
$ErrorActionPreference='Stop'
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
function RJ($p){ if(!(Test-Path $p)){ return $null } try{ Get-Content $p -Raw | ConvertFrom-Json }catch{ $null } }
$timeline=RJ (Join-Path $worldsDir ("timeline-"+$World+".json"))
$md=@("# World Scenes — "+$World,"")
if($timeline -and $timeline.events){ foreach($e in $timeline.events){ $md += "## " + ($e.title ?? "Event"); $md += ""; $md += "**When:** " + ($e.when ?? "—"); $md += "**Where:** " + ($e.location ?? "—"); $md += "**Tags:** " + ((($e.tags ?? @()) -join ", ")  ?? "—"); $md += ""; $md += ($e.summary ?? "…"); $md += "" } } else { $md += "_No timeline yet; stub scenes._" }
$exportDir=Join-Path $worldsDir 'exports'; if(!(Test-Path $exportDir)){ New-Item -ItemType Directory -Force -Path $exportDir|Out-Null }
$scenesPath=Join-Path $exportDir ("Scenes-"+$World+".md"); Set-Content $scenesPath -Value ($md -join "`n") -Encoding UTF8; Write-Host "Wrote $scenesPath"
