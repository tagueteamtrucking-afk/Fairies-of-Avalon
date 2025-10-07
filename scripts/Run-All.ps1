
param([Parameter()][object]$WorldCount=3,[Parameter()][object]$NonInteractive=$false)
Import-Module -Name (Join-Path $PSScriptRoot 'AsInt.psm1')
$wc = As-Int -Value $WorldCount
$Root = Split-Path -Parent $PSScriptRoot
$Apps = Join-Path (Join-Path $Root 'pages') 'apps'
$dirs = @('alexandria/worlds','alexandria/dm','tracy/artboards','overseers','charlotte/pipelines','charlotte/voiceovers','carol/plans','jem/programs','stella/components')
foreach($d in $dirs){ $null = New-Item -ItemType Directory -Path (Join-Path $Apps $d) -Force }
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
function Write-Json($p,$o){ [IO.File]::WriteAllText($p, ($o|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8) }
Write-Json (Join-Path $Apps 'alexandria/worlds/index.json') @{ updated=$now; items=@() }
Write-Json (Join-Path $Apps 'alexandria/dm/index.json') @{ updated=$now; worlds=@() }
Write-Json (Join-Path $Apps 'tracy/artboards/index.json') @{ updated=$now; items=@(@{ id="board1"; title="Homepage hero"; status="draft" }) }
Write-Json (Join-Path $Apps 'charlotte/pipelines/index.json') @{ updated=$now; pipelines=@(@{ id="welcome"; text="Welcome to Avalon." }) }
Write-Json (Join-Path $Apps 'carol/plans/index.json') @{ updated=$now; plans=@() }
Write-Json (Join-Path $Apps 'jem/programs/index.json') @{ updated=$now; programs=@() }
Write-Json (Join-Path $Apps 'stella/components/index.json') @{ updated=$now; items=@() }
Write-Host "Run-All: scaffolds written."
