# Generate a placeholder artboard brief
$Root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path (Join-Path $Root 'pages/apps/tracy') 'artboards'
$null = New-Item -ItemType Directory -Path $dir -Force
$now = (Get-Date).ToUniversalTime().ToString("s") + "Z"
[IO.File]::WriteAllText((Join-Path $dir 'index.json'), (@{updated=$now;items=@(@{id="hero";title="Homepage Hero";prompt="Parchment/treasure-map hero"})}|ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Tracy: wrote artboard index."
