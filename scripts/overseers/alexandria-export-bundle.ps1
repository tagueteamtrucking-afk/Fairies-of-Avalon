param([Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$World)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$worldsDir=Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
$exportDir=Join-Path $worldsDir 'exports'; if(!(Test-Path $exportDir)){ New-Item -ItemType Directory -Force -Path $exportDir|Out-Null }
$patterns=@("seed-$World.json","bible-$World.json","atlas-$World.json","timeline-$World.json","npcs-$World.json","codex/figures-$World.json","reports/continuity-$World.json","exports/Scenes-$World.md")
$files=@(); foreach($pat in $patterns){ $p=Join-Path $worldsDir $pat; $f=Get-ChildItem -LiteralPath $p -ErrorAction SilentlyContinue; if($f){ $files += $f.FullName } }
$zipPath=Join-Path $exportDir ("WorldBundle-"+$World+".zip"); if(Test-Path $zipPath){ Remove-Item -LiteralPath $zipPath -Force }
$zip=[System.IO.Compression.ZipFile]::Open($zipPath,[System.IO.Compression.ZipArchiveMode]::Create)
foreach($f in $files){ $rel=$f.Replace($worldsDir,"").TrimStart('\','/'); [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$f,$rel)|Out-Null }
$zip.Dispose(); Write-Host "Wrote $zipPath"
