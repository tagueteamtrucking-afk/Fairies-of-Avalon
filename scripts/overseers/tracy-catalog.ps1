[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
$root = (Resolve-Path $RepoRoot).Path
function Rel([string]$p){ return '/' + ($p.Substring($root.Length).TrimStart('\','/') -replace '\\','/') }

$models = @()
$wings  = @()
$walls  = @()

$mr = Join-Path $RepoRoot "asset/models"
if (Test-Path $mr){ $models = Get-ChildItem $mr -Recurse -File | Where-Object { $_.Extension -match '\.vrm$' } | ForEach-Object { [pscustomobject]@{ type='model'; path=(Rel $_.FullName); bytes=$_.Length } } }
$wr = Join-Path $RepoRoot "asset/wings"
if (Test-Path $wr){ 
  $wings = Get-ChildItem $wr -Recurse -File | Where-Object { $_.Extension -match '\.(fbx|glb|gltf|png|jpg|jpeg|webp)$' } | ForEach-Object { [pscustomobject]@{ type='wing'; path=(Rel $_.FullName); bytes=$_.Length } }
}
$wd = Join-Path $RepoRoot "asset/textures/wallpapers"
if (Test-Path $wd){
  $walls = Get-ChildItem $wd -File | ForEach-Object { [pscustomobject]@{ type='wallpaper'; path=(Rel $_.FullName); bytes=$_.Length } }
}

$outDir = Join-Path $RepoRoot "pages/apps/tracy"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$cat = @{ models=$models; wings=$wings; wallpapers=$walls; generated=(Get-Date).ToUniversalTime().ToString("s") + "Z" }
($cat | ConvertTo-Json -Depth 40) | Set-Content -Path (Join-Path $outDir "catalog.json") -Encoding utf8NoBOM
Write-Host "Catalog written."
exit 0
