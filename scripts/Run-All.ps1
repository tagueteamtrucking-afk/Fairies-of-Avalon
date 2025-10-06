param([Parameter()][object]$WorldCount=3,[Parameter()][object]$NonInteractive=$false)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$wc = As-Int -Value $WorldCount
$Root = Split-Path -Parent $PSScriptRoot
$Apps = Join-Path (Join-Path $Root 'pages') 'apps'
$paths = @('alexandria/worlds','tracy/artboards','overseers','charlotte/pipelines','charlotte/voiceovers','carol/plans','jem/programs','stella/components')
foreach($p in $paths){ $null = New-Item -ItemType Directory -Path (Join-Path $Apps $p) -Force }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
function WJ($p,$o){[IO.File]::WriteAllText($p, ($o|ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)}
# Minimal scaffolds
$worlds = Join-Path $Apps 'alexandria/worlds'
$items = @()
for($i=1;$i -le $wc;$i++){ $slug="auto-$i"; $file="world-$slug.json"; WJ (Join-Path $worlds $file) @{id="world-$slug";title="Auto World #$i";summary="Generated locally";lore="Placeholder";seedPrompts=@("Map and landmarks","Two NPCs");created=$now;version="1.0.0"}; $items += @{id="world-$slug";slug=$slug;title="Auto World #$i";summary="Generated locally";file=$file} }
WJ (Join-Path $worlds 'index.json') @{updated=$now;items=$items}
WJ (Join-Path $Apps 'tracy/artboards/index.json') @{updated=$now;items=@(@{id="art-"+[guid]::NewGuid().ToString("N").Substring(0,6);title="Idea Board";status="draft";prompt="Homepage hero."})}
WJ (Join-Path $Apps 'overseers/vrm-index.json') @{updated=$now;avatars=@(@{id="vrm-alexandria";name="Alexandria";uri="vrm/alexandria.vrm"},@{id="vrm-charlotte";name="Charlotte";uri="vrm/charlotte.vrm"})}
WJ (Join-Path $Apps 'charlotte/pipelines/index.json') @{updated=$now;pipelines=@(@{id="welcome";text="Welcome to Avalon. Build the AI and let them build the site.";voice="en-US-AriaNeural";format="riff-16khz-16bit-mono-pcm"})}
if(-not (Test-Path (Join-Path $Apps 'charlotte/voiceovers/index.json'))){ WJ (Join-Path $Apps 'charlotte/voiceovers/index.json') @{updated=$now;items=@()} }
WJ (Join-Path $Apps 'carol/plans/index.json') @{updated=$now;plans=@(@{id="site-v1";title="Site v1";tasks=@("Wire homepage","Run LLM Bridges","Publish Pages")})}
WJ (Join-Path $Apps 'jem/programs/index.json') @{updated=$now;programs=@(@{id="healthcheck";title="Health Check";type="script";entry="scripts/Run-All.ps1"})}
WJ (Join-Path $Apps 'stella/components/index.json') @{updated=$now;items=@(@{id="component-map-button";slug="map-button";title="Treasure-Map Button";summary="Globe/treasure-map CTA";file="component-map-button.json"})}
WJ (Join-Path $Apps 'stella/components/component-map-button.json') @{id="component-map-button";title="Treasure-Map Button";purpose="CTA for world generation";tokens=@{bg="#f1e2c2";fg="#1f2937";border="rgba(0,0,0,.28)"};html="<a class='btn map' href='#'><span class='icon' aria-hidden='true'>🗺️</span>Generate Worlds</a>";css=".btn.map{background:#f1e2c2;color:#1f2937;border:1px solid rgba(0,0,0,.28);box-shadow:inset 0 0 0 1px rgba(0,0,0,.06);position:relative;overflow:hidden}.btn.map:hover{background:#ead9b5}.btn .icon{margin-right:8px;font-size:1.1em}.btn.map::after{content:'';position:absolute;left:-10%;top:50%;width:120%;height:2px;background-image:linear-gradient(to right,rgba(0,0,0,.35) 50%,rgba(0,0,0,0) 0%);background-size:10px 2px;background-repeat:repeat-x;opacity:.25;transform:rotate(-6deg);pointer-events:none}";created=$now;version="1.0.0"}
Write-Host "Run-All: scaffolds written."
