$root=Split-Path -Parent $PSScriptRoot
$paths=@(
  Join-Path $root 'asset/models',
  Join-Path $root 'asset/models/wingless',
  Join-Path $root 'asset/models/with-wings',
  Join-Path $root 'asset/winged-models'
) | Where-Object { Test-Path $_ }
$vrms=@()
foreach($p in $paths){ $vrms += Get-ChildItem -Recurse -File -Path $p -Filter *.vrm -ErrorAction SilentlyContinue }
$outDir=Join-Path $root 'pages/apps/nina'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
$list=$vrms | ForEach-Object { @{ name=$_.Name; rel=($_.FullName.Replace($root,"").Replace("\","/").TrimStart("/")) } }
[IO.File]::WriteAllText((Join-Path $outDir 'vrm-index.json'), ($list|ConvertTo-Json -Depth 4), [Text.Encoding]::UTF8)
Write-Host "VRM index written."
