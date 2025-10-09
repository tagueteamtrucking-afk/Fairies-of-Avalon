$root=Split-Path -Parent $PSScriptRoot
$apps=Join-Path $root 'pages/apps'
$manifest=@()
Get-ChildItem -Directory $apps | ForEach-Object {
  $m=@{ id=$_.Name; path="/pages/apps/$($_.Name)/" }
  $manifest += $m
}
$outDir=Join-Path $root 'pages/apps/charlotte'; New-Item -ItemType Directory -Force -Path $outDir|Out-Null
[IO.File]::WriteAllText((Join-Path $outDir 'manifest.json'), ($manifest|ConvertTo-Json -Depth 4), [Text.Encoding]::UTF8)
Write-Host "Manifest written."
