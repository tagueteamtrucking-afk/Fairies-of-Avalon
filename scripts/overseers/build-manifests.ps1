[CmdletBinding()]
param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = 'Stop'

try { Import-Module powershell-yaml -ErrorAction Stop }
catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function Make-Slug([string]$name) {
  if (-not $name) { return "" }
  return ($name -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
}
function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }
function To-Rel([string]$p){
  $root = (Resolve-Path -LiteralPath $RepoRoot).Path
  $full = (Resolve-Path -LiteralPath $p).Path
  $rel  = $full.Substring($root.Length).TrimStart('\','/')
  return ($rel -replace '\\','/')
}

# Load Memory and paths
$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem     = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml

$layout = $mem.assets.layout
$modelsRootLegacy = Join-Path $RepoRoot $layout.models_root_legacy
$winglessDir      = Join-Path $RepoRoot $layout.wingless_vrms
$prewingedDir     = Join-Path $RepoRoot $layout.with_wings_vrms
$wingedAliasDir   = Join-Path $RepoRoot $layout.with_wings_alias
$wingsMeshDir     = Join-Path $RepoRoot $layout.wings_models
$wingsTexDir      = Join-Path $RepoRoot $layout.wings_textures
$modelsManifest   = Join-Path $RepoRoot $layout.models_manifest
$wingsManifest    = Join-Path $RepoRoot $layout.wings_manifest
$wallpapersDir    = Join-Path $RepoRoot $layout.wallpapers

$pagesRoot        = Join-Path $RepoRoot $mem.hosting.pages_root
$microappsRoot    = Join-Path $RepoRoot $mem.hosting.microapps_path
$assistantsJson   = Join-Path $RepoRoot "pages/apps/overseers/assistants.json"
$progressFile     = Join-Path $RepoRoot $mem.runtime.paths.progress_file

# Gather VRM lists
$wingless = @()
$prewinged = @()

if (Test-Path $winglessDir)  { $wingless += Get-ChildItem $winglessDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }
if (Test-Path $prewingedDir) { $prewinged += Get-ChildItem $prewingedDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }
if (Test-Path $wingedAliasDir){ $prewinged += Get-ChildItem $wingedAliasDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }

# Legacy classification in models_root_legacy
if (Test-Path $modelsRootLegacy) {
  $files = Get-ChildItem $modelsRootLegacy -Filter *.vrm -File
  foreach ($f in $files) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLowerInvariant()
    if ($f.DirectoryName -match [regex]::Escape((Resolve-Path -LiteralPath $winglessDir -ErrorAction SilentlyContinue)?.Path) `
        -or $f.DirectoryName -match [regex]::Escape((Resolve-Path -LiteralPath $prewingedDir -ErrorAction SilentlyContinue)?.Path)) {
      continue
    }
    if ($name.EndsWith("_wings") -or $name.EndsWith("-wings")) { $prewinged += (To-Rel $f.FullName) }
    else { $wingless += (To-Rel $f.FullName) }
  }
}

# De-dupe (case-insensitive)
$wingless  = $wingless  | Sort-Object -Unique
$prewinged = $prewinged | Sort-Object -Unique

# Build byAvatar map (best-effort)
$avatars = @($mem.avatars_present)
$byAvatar = @{}
foreach ($a in $avatars) {
  $slug = Make-Slug $a
  $expect = "$($a).vrm"
  $candidates = @()
  $candidates += $wingless | Where-Object { $_.Split('/')[-1] -ieq $expect }
  $candidates += $prewinged | Where-Object { $_.Split('/')[-1] -ieq $expect }
  if (-not $candidates -or $candidates.Count -eq 0) {
    # try lowercased simple slug
    $candidates += $wingless | Where-Object { $_.ToLower().Contains(("$slug.vrm")) }
    $candidates += $prewinged | Where-Object { $_.ToLower().Contains(("$slug.vrm")) }
  }
  if ($candidates.Count -gt 0) {
    $byAvatar[$a] = $candidates[0]
  }
}

# Write models manifest
New-Item -ItemType Directory -Force -Path (Split-Path $modelsManifest -Parent) | Out-Null
$modelsObj = @{
  generated = (IsoNow)
  wingless = $wingless
  prewinged = $prewinged
  byAvatar = $byAvatar
}
$modelsJson = ($modelsObj | ConvertTo-Json -Depth 6)
Set-Content -Path $modelsManifest -Value $modelsJson -Encoding utf8NoBOM

# Wings manifest (group meshes + textures by number)
$wings = @{}
if (Test-Path $wingsMeshDir) {
  Get-ChildItem $wingsMeshDir -Filter *.fbx -File | ForEach-Object {
    $n = $_.BaseName
    if ($n -match '(?i)^wing(?<id>\d+)$') {
      $id = $Matches['id']
      if (-not $wings.ContainsKey($id)) { $wings[$id] = @{ mesh = $null; textures = @{} } }
      $wings[$id].mesh = To-Rel $_.FullName
    }
  }
}
if (Test-Path $wingsTexDir) {
  Get-ChildItem $wingsTexDir -File | Where-Object { $_.Extension -match 'png|jpg|jpeg|webp' } | ForEach-Object {
    $bn = $_.BaseName
    $name = ($bn -replace '\(.*\)', '')  # strip (1)
    if ($name -match '(?i)^wing(?<id>\d+)(?<suf>_c|_e|_nrm)?$') {
      $id  = $Matches['id']
      $suf = $Matches['suf']
      if (-not $wings.ContainsKey($id)) { $wings[$id] = @{ mesh = $null; textures = @{} } }
      $rel = To-Rel $_.FullName
      switch -Regex ($suf) {
        "_c"   { $wings[$id].textures.color    = $rel; break }
        "_e"   { $wings[$id].textures.emissive = $rel; break }
        "_nrm" { $wings[$id].textures.normal   = $rel; break }
        default { $wings[$id].textures.base    = $rel; break }
      }
    }
  }
}

New-Item -ItemType Directory -Force -Path (Split-Path $wingsManifest -Parent) | Out-Null
$wingsObj = @{
  generated = (IsoNow)
  wings = $wings
}
$wingsJson = ($wingsObj | ConvertTo-Json -Depth 6)
Set-Content -Path $wingsManifest -Value $wingsJson -Encoding utf8NoBOM

# Assistants list for Hub
$assist = @()
foreach ($a in $avatars) {
  $slug = Make-Slug $a
  $pubPath = "/apps/$slug/"
  $exists  = Test-Path (Join-Path $microappsRoot $slug "index.html")
  $assist += @{ name = $a; id = $slug; path = $pubPath; microapp_exists = $exists }
}
New-Item -ItemType Directory -Force -Path (Split-Path $assistantsJson -Parent) | Out-Null
$assistJson = ($assist | ConvertTo-Json -Depth 4)
Set-Content -Path $assistantsJson -Value $assistJson -Encoding utf8NoBOM

# WPI (Wallpaper Power Index)
$wallpapersTotal = [int]($mem.assets.budgets.wallpapers_total)
$wallpaperFiles = @()
if (Test-Path $wallpapersDir) {
  $wallpaperFiles = Get-ChildItem $wallpapersDir -File | Where-Object { $_.Extension -match 'png|jpg|jpeg|webp' }
}
$count = $wallpaperFiles.Count
$wpi = 0
if ($wallpapersTotal -gt 0) {
  $ratio = [double]([Math]::Min($count, $wallpapersTotal)) / [double]$wallpapersTotal
  $wpi = [int][Math]::Round($ratio * 100)
}

# Merge into progress.json (non-destructive)
$progress = @{}
if (Test-Path $progressFile) {
  try { $progress = Get-Content -Raw -Path $progressFile | ConvertFrom-Json -Depth 50 } catch { $progress = @{} }
}
if (-not $progress) { $progress = @{} }
if (-not $progress.telemetry) { $progress.telemetry = @{} }
$progress.telemetry.wallpaper_power_index = $wpi
$progress.telemetry.wallpapers_count = $count
$progress.telemetry.wallpapers_total = $wallpapersTotal
$progress.telemetry.updated = (IsoNow)

$progressJson = $progress | ConvertTo-Json -Depth 50
New-Item -ItemType Directory -Force -Path (Split-Path $progressFile -Parent) | Out-Null
Set-Content -Path $progressFile -Value $progressJson -Encoding utf8NoBOM

Write-Host "Manifests built. Wingless=$($wingless.Count) Prewinged=$($prewinged.Count) Wings=$($wings.Keys.Count) WPI=$wpi"
