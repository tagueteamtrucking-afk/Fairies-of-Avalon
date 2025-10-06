param([Parameter()][object]$WorldCount=3,[Parameter()][object]$NonInteractive=$false)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$wc = As-Int -Value $WorldCount
$Root = Split-Path -Parent $PSScriptRoot
$Apps = Join-Path (Join-Path $Root 'pages') 'apps'
$dirs = @('alexandria/worlds','tracy/artboards','overseers','charlotte/pipelines','charlotte/voiceovers','carol/plans','jem/programs','stella/components')
foreach($d in $dirs){ $null = New-Item -ItemType Directory -Path (Join-Path $Apps $d) -Force }

$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
function Write-Json($p,$o){ [IO.File]::WriteAllText($p, ($o|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8) }

# Alexandria scaffold
$worlds = Join-Path $Apps 'alexandria/worlds'; $items=@()
for($i=1;$i -le $wc;$i++){ $slug="auto-$i"; $file="world-$slug.json"
  Write-Json (Join-Path $worlds $file) @{ id="world-$slug"; title="Auto World #$i"; summary="Scaffold"; lore="Placeholder"; seedPrompts=@("Map","NPCs"); created=$now; version="1.0.0" }
  $items += @{ id="world-$slug"; slug=$slug; title="Auto World #$i"; summary="Scaffold"; file=$file }
}
Write-Json (Join-Path $worlds 'index.json') @{ updated=$now; items=$items }

# Tracy
Write-Json (Join-Path $Apps 'tracy/artboards/index.json') @{ updated=$now; items=@(@{ id="board1"; title="Homepage hero"; status="draft" }) }

# Overseers
Write-Json (Join-Path $Apps 'overseers/vrm-index.json') @{ updated=$now; avatars=@(@{id="vrm-alexandria";name="Alexandria"}) }

# Charlotte pipelines
Write-Json (Join-Path $Apps 'charlotte/pipelines/index.json') @{ updated=$now; pipelines=@(@{ id="welcome"; text="Welcome to Avalon."; voice="alloy" }) }
if (-not (Test-Path (Join-Path $Apps 'charlotte/voiceovers/index.json'))) { Write-Json (Join-Path $Apps 'charlotte/voiceovers/index.json') @{ updated=$now; items=@() } }

# Carol
Write-Json (Join-Path $Apps 'carol/plans/index.json') @{ updated=$now; plans=@(@{ id="site-v1"; title="Site v1"; tasks=@("Wire homepage","Run LLM Bridges","Publish Pages") }) }

# Jem
Write-Json (Join-Path $Apps 'jem/programs/index.json') @{ updated=$now; programs=@(@{ id="healthcheck"; title="Health Check"; type="script"; entry="scripts/Run-All.ps1" }) }

# Stella
Write-Json (Join-Path $Apps 'stella/components/index.json') @{ updated=$now; items=@(@{ id="map-button"; slug="map-button"; title="Treasure-Map Button"; summary="Globe CTA"; file="component-map-button.json" }) }
Write-Json (Join-Path $Apps 'stella/components/component-map-button.json') @{ id="map-button"; title="Treasure-Map Button"; blueprint=@{ html="<a class='btn map' href='#'><span class='icon'>🗺️</span>Generate Worlds</a>"; css=".btn.map{background:#f1e2c2;padding:12px 16px;border:1px solid rgba(0,0,0,.25)} .btn .icon{margin-right:8px}" } }
Write-Host "Run-All: scaffolds written."
