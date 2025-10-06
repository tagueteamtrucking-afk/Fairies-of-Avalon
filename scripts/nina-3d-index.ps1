# Build simple VRM/3D index
$Root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path (Join-Path $Root 'pages/apps/overseers') 'vrm-index.json'
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
[IO.File]::WriteAllText($dir, (@{updated=$now;avatars=@(@{id="alexandria";name="Alexandria";uri="vrm/alexandria.vrm"})}|ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Nina: wrote 3D index."
