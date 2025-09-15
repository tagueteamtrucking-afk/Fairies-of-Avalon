[CmdletBinding()]
param([string]$RepoRoot=".")

# Be strict about stopping on real errors inside try/catch blocks only.
$ErrorActionPreference='Stop'

# --- Helpers ---------------------------------------------------------------
function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }
function To-Rel([string]$p){
  if (-not $p) { return $null }
  $root=(Resolve-Path -LiteralPath $RepoRoot).Path
  $full=(Resolve-Path -LiteralPath $p).Path
  return ($full.Substring($root.Length)).TrimStart('\','/') -replace '\\','/'
}
function Last-Segment([string]$path){
  if (-not $path) { return $null }
  ($path -split '/') | Select-Object -Last 1
}
function Make-Slug([string]$n){ if(-not $n){return ""}; return ($n -replace '[^A-Za-z0-9]','').ToLowerInvariant() }

# Try to ensure YAML module is present
try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

# --- Load Memory with safe fallbacks --------------------------------------
$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem = @{}
try { $mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml } catch {
  Write-Host "::warning:: Unable to parse Memory; using safe defaults for paths."
  $mem = @{}
}

# Default layout (if Memory missing keys)
$layout = $null
if ($mem -and $mem.assets -and $mem.assets.layout) { $layout = $mem.assets.layout }
if (-not $layout) {
  $layout = [ordered]@{
    models_root_legacy = "asset/models"
    wingless_vrms      = "asset/models/wingless"
    with_wings_vrms    = "asset/models/with-wings"
    with_wings_alias   = "asset/winged-models"
    wings_models       = "asset/wings"
    wings_textures     = "asset/wings/textures"
    models_manifest    = "asset/models/models.json"
    wings_manifest     = "asset/wings/manifest.json"
    wallpapers         = "asset/textures/wallpapers"
  }
}

# Default hosting paths
$pagesRoot     = ($mem.hosting.pages_root)     ; if (-not $pagesRoot)     { $pagesRoot     = "pages" }
$microappsPath = ($mem.hosting.microapps_path) ; if (-not $microappsPath) { $microappsPath = "pages/apps" }

# Resolve directories/files
$modelsRootLegacy = Join-Path $RepoRoot $layout.models_root_legacy
$winglessDir      = Join-Path $RepoRoot $layout.wingless_vrms
$prewingedDir     = Join-Path $RepoRoot $layout.with_wings_vrms
$wingedAliasDir   = Join-Path $RepoRoot $layout.with_wings_alias
$wingsMeshDir     = Join-Path $RepoRoot $layout.wings_models
$wingsTexDir      = Join-Path $RepoRoot $layout.wings_textures
$modelsManifest   = Join-Path $RepoRoot $layout.models_manifest
$wingsManifest    = Join-Path $RepoRoot $layout.wings_manifest
$wallpapersDir    = Join-Path $RepoRoot $layout.wallpapers

$microappsRoot  = Join-Path $RepoRoot $microappsPath
$assistantsJson = Join-Path $RepoRoot "pages/apps/overseers/assistants.json"
$progressFile   = Join-Path $RepoRoot "pages/apps/overseers/progress.json"
$wallpapersJson = Join-Path $RepoRoot "pages/apps/overseers/wallpapers.json"

# Collect VRMs (null-safe)
$wingless=@(); $prewinged=@()

if (Test-Path $winglessDir)   { $wingless  += Get-ChildItem $winglessDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }
if (Test-Path $prewingedDir)  { $prewinged += Get-ChildItem $prewingedDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }
if (Test-Path $wingedAliasDir){ $prewinged += Get-ChildItem $wingedAliasDir -Filter *.vrm -File -Recurse | ForEach-Object { To-Rel $_.FullName } }

# Legacy classification if any VRMs are directly under asset/models
if (Test-Path $modelsRootLegacy) {
  $legacy = Get-ChildItem $modelsRootLegacy -Filter *.vrm -File
  foreach ($f in $legacy) {
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name).ToLowerInvariant()
    # If subfolders exist and file is inside them, skip (already counted)
    if ($f.FullName -like (Join-Path $winglessDir '*') -or $f.FullName -like (Join-Path $prewingedDir '*')) { continue }
    if ($name.EndsWith('_wings') -or $name.EndsWith('-wings')) { $prewinged += (To-Rel $f.FullName) }
    else { $wingless += (To-Rel $f.FullName) }
  }
}

$wingless  = $wingless  | Where-Object { $_ } | Sort-Object -Unique
$prewinged = $prewinged | Where-Object { $_ } | Sort-Object -Unique

# byAvatar mapping
$avatars = @()
if ($mem -and $mem.avatars_present) { $avatars = @($mem.avatars_present) }
$byAvatar=@{}
foreach($a in $avatars){
  $slug = Make-Slug $a
  $expect = "$a.vrm"
  $cand = @($wingless + $prewinged) | Where-Object {
    (Last-Segment $_) -ieq $expect
  }
  if(-not $cand -or $cand.Count -eq 0){
    $cand = @($wingless + $prewinged) | Where-Object {
      $_.ToLower().Contains("$slug.vrm")
    }
  }
  if($cand -and $cand.Count -gt 0){ $byAvatar[$a] = $cand[0] }
}

# Write models manifest
New-Item -ItemType Directory -Force -Path (Split-Path $modelsManifest -Parent) | Out-Null
@{
  generated = (IsoNow)
  wingless = $wingless
  prewinged = $prewinged
  byAvatar = $byAvatar
} | ConvertTo-Json -Depth 6 | Set-Content -Path $modelsManifest -Encoding utf8NoBOM

# Wings manifest (mesh+textures grouped by id)
$wings=@{}
if (Test-Path $wingsMeshDir) {
  Get-ChildItem $wingsMeshDir -Filter *.fbx -File | ForEach-Object {
    $bn = $_.BaseName
    if ($bn -match '(?i)^wing(?<id>\d+)$'){
      $id = $Matches['id']
      if (-not $wings.ContainsKey($id)) { $wings[$id] = @{ mesh = $null; textures = @{} } }
      $wings[$id].mesh = To-Rel $_.FullName
    }
  }
}
if (Test-Path $wingsTexDir) {
  Get-ChildItem $wingsTexDir -File | Where-Object { $_.Extension -match 'png|jpe?g|webp' } | ForEach-Object {
    $name = ($_.BaseName -replace '\(.*\)','') # strip (1)
    if ($name -match '(?i)^wing(?<id>\d+)(?<suf>_c|_e|_nrm)?$'){
      $id  = $Matches['id']; $suf = $Matches['suf']
      if (-not $wings.ContainsKey($id)) { $wings[$id] = @{ mesh = $null; textures = @{} } }
      $rel = To-Rel $_.FullName
      if ($suf -eq '_c')     { $wings[$id].textures.color    = $rel }
      elseif ($suf -eq '_e') { $wings[$id].textures.emissive = $rel }
      elseif ($suf -eq '_nrm'){ $wings[$id].textures.normal  = $rel }
      else { $wings[$id].textures.base = $rel }
    }
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $wingsManifest -Parent) | Out-Null
@{ generated=(IsoNow); wings=$wings } | ConvertTo-Json -Depth 6 | Set-Content -Path $wingsManifest -Encoding utf8NoBOM

# Assistants list for Hub
$assist=@()
foreach($a in $avatars){
  $slug=Make-Slug $a
  $pub="/apps/$slug/"
  $exists=Test-Path (Join-Path $microappsRoot $slug "index.html")
  $assist += @{ name=$a; id=$slug; path=$pub; microapp_exists=$exists }
}
New-Item -ItemType Directory -Force -Path (Split-Path $assistantsJson -Parent) | Out-Null
$assist | ConvertTo-Json -Depth 4 | Set-Content -Path $assistantsJson -Encoding utf8NoBOM

# Wallpapers manifest + WPI
$wallList=@()
if (Test-Path $wallpapersDir) {
  Get-ChildItem $wallpapersDir -File | Where-Object { $_.Extension -match 'png|jpe?g|webp' } | Sort-Object Name | ForEach-Object {
    $wallList += @{ path = To-Rel $_.FullName; size = $_.Length; name = $_.Name }
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $wallpapersJson -Parent) | Out-Null
$wallList | ConvertTo-Json -Depth 4 | Set-Content -Path $wallpapersJson -Encoding utf8NoBOM

# Compute WPI
$wallTotal = 20
try { if ($mem.assets.budgets.wallpapers_total) { $wallTotal = [int]$mem.assets.budgets.wallpapers_total } } catch {}
$count = $wallList.Count
$wpi = if ($wallTotal -gt 0) { [int][Math]::Round(([Math]::Min($count,$wallTotal)/[double]$wallTotal)*100) } else { 0 }

# Merge into progress.json
$progress=@{}
if (Test-Path $progressFile) { try { $progress = Get-Content -Raw -Path $progressFile | ConvertFrom-Json -Depth 50 } catch { $progress=@{} } }
if (-not $progress) { $progress=@{} }
if (-not $progress.telemetry) { $progress.telemetry=@{} }
$progress.telemetry.wallpaper_power_index=$wpi
$progress.telemetry.wallpapers_count=$count
$progress.telemetry.wallpapers_total=$wallTotal
$progress.telemetry.updated=(IsoNow)
New-Item -ItemType Directory -Force -Path (Split-Path $progressFile -Parent) | Out-Null
($progress | ConvertTo-Json -Depth 50) | Set-Content -Path $progressFile -Encoding utf8NoBOM

Write-Host "Manifests built: wingless=$($wingless.Count) prewinged=$($prewinged.Count) wings=$($wings.Keys.Count) wallpapers=$count WPI=$wpi"
# Do NOT throw at the end; script exits 0 by default.
