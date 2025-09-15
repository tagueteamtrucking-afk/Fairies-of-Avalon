[CmdletBinding()]
param([string]$RepoRoot=".")

$ErrorActionPreference='Stop'
try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function Make-Slug([string]$n){ if(-not $n){return ""}; return ($n -replace '[^A-Za-z0-9]','').ToLowerInvariant() }
function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }
function To-Rel([string]$p){ $root=(Resolve-Path -LiteralPath $RepoRoot).Path; $full=(Resolve-Path -LiteralPath $p).Path; ($full.Substring($root.Length)).TrimStart('\','/') -replace '\\','/' }

# Memory + paths
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

$pagesRoot      = Join-Path $RepoRoot $mem.hosting.pages_root
$microappsRoot  = Join-Path $RepoRoot $mem.hosting.microapps_path
$assistantsJson = Join-Path $RepoRoot "pages/apps/overseers/assistants.json"
$progressFile   = Join-Path $RepoRoot $mem.runtime.paths.progress_file
$wallpapersJson = Join-Path $RepoRoot "pages/apps/overseers/wallpapers.json"

# Collect VRM
$wingless=@(); $prewinged=@()
if (Test-Path $winglessDir)   { $wingless  += Get-ChildItem $winglessDir -Filter *.vrm -File -Recurse | % { To-Rel $_.FullName } }
if (Test-Path $prewingedDir)  { $prewinged += Get-ChildItem $prewingedDir -Filter *.vrm -File -Recurse | % { To-Rel $_.FullName } }
if (Test-Path $wingedAliasDir){ $prewinged += Get-ChildItem $wingedAliasDir -Filter *.vrm -File -Recurse | % { To-Rel $_.FullName } }

if (Test-Path $modelsRootLegacy) {
  $files = Get-ChildItem $modelsRootLegacy -Filter *.vrm -File
  foreach ($f in $files) {
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name).ToLowerInvariant()
    if ($name.EndsWith("_wings") -or $name.EndsWith("-wings")) { $prewinged += (To-Rel $f.FullName) }
    else { $wingless += (To-Rel $f.FullName) }
  }
}
$wingless  = $wingless  | Sort-Object -Unique
$prewinged = $prewinged | Sort-Object -Unique

# byAvatar
$avatars=@($mem.avatars_present)
$byAvatar=@{}
foreach($a in $avatars){
  $slug=Make-Slug $a; $expect="$a.vrm"
  $cand = @($wingless + $prewinged) | ? { $_.Split('/')[-1] -ieq $expect }
  if(-not $cand -or $cand.Count -eq 0){ $cand = @($wingless + $prewinged) | ? { $_.ToLower().Contains("$slug.vrm") } }
  if($cand.Count -gt 0){ $byAvatar[$a]=$cand[0] }
}

# Write models manifest
New-Item -ItemType Directory -Force -Path (Split-Path $modelsManifest -Parent) | Out-Null
@{
  generated = (IsoNow)
  wingless = $wingless
  prewinged = $prewinged
  byAvatar = $byAvatar
} | ConvertTo-Json -Depth 6 | Set-Content -Path $modelsManifest -Encoding utf8NoBOM

# Wings manifest: consolidate meshes + textures (if file exists, we still rebuild from disk to keep fresh)
$wings=@{}
if (Test-Path $wingsMeshDir) {
  Get-ChildItem $wingsMeshDir -Filter *.fbx -File | % {
    if ($_.BaseName -match '(?i)^wing(?<id>\d+)$'){ $id=$Matches.id; if(-not $wings.ContainsKey($id)){ $wings[$id]=@{ mesh=$null; textures=@{} } }; $wings[$id].mesh = To-Rel $_.FullName }
  }
}
if (Test-Path $wingsTexDir) {
  Get-ChildItem $wingsTexDir -File | ? { $_.Extension -match 'png|jpe?g|webp' } | % {
    $name = ($_.BaseName -replace '\(.*\)','')
    if ($name -match '(?i)^wing(?<id>\d+)(?<suf>_c|_e|_nrm)?$'){
      $id=$Matches.id; $suf=$Matches.suf
      if(-not $wings.ContainsKey($id)){ $wings[$id]=@{ mesh=$null; textures=@{} } }
      $rel = To-Rel $_.FullName
      switch ($suf) {
        '_c'   { $wings[$id].textures.color    = $rel }
        '_e'   { $wings[$id].textures.emissive = $rel }
        '_nrm' { $wings[$id].textures.normal   = $rel }
        default{ $wings[$id].textures.base     = $rel }
      }
    }
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $wingsManifest -Parent) | Out-Null
@{ generated=(IsoNow); wings=$wings } | ConvertTo-Json -Depth 6 | Set-Content -Path $wingsManifest -Encoding utf8NoBOM

# Assistants list for Hub
$assist=@()
foreach($a in $avatars){
  $slug=Make-Slug $a; $pub="/apps/$slug/"; $exists=Test-Path (Join-Path $microappsRoot $slug "index.html")
  $assist += @{ name=$a; id=$slug; path=$pub; microapp_exists=$exists }
}
New-Item -ItemType Directory -Force -Path (Split-Path $assistantsJson -Parent) | Out-Null
$assist | ConvertTo-Json -Depth 4 | Set-Content -Path $assistantsJson -Encoding utf8NoBOM

# Wallpapers list + WPI
$wallList=@()
if (Test-Path $wallpapersDir) {
  Get-ChildItem $wallpapersDir -File | ? { $_.Extension -match 'png|jpe?g|webp' } | Sort-Object Name | % {
    $wallList += @{ path = To-Rel $_.FullName; size = $_.Length; name = $_.Name }
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path $wallpapersJson -Parent) | Out-Null
$wallList | ConvertTo-Json -Depth 4 | Set-Content -Path $wallpapersJson -Encoding utf8NoBOM

$wallTotal=[int]($mem.assets.budgets.wallpapers_total); $count=$wallList.Count
$wpi = if($wallTotal -gt 0){ [int][Math]::Round(([Math]::Min($count,$wallTotal)/[double]$wallTotal)*100) } else { 0 }

# Merge telemetry into progress.json
$progress=@{}
if (Test-Path $progressFile) { try{ $progress = Get-Content -Raw -Path $progressFile | ConvertFrom-Json -Depth 50 } catch { $progress=@{} } }
if (-not $progress) { $progress=@{} }
if (-not $progress.telemetry) { $progress.telemetry=@{} }
$progress.telemetry.wallpaper_power_index=$wpi
$progress.telemetry.wallpapers_count=$count
$progress.telemetry.wallpapers_total=$wallTotal
$progress.telemetry.updated=(IsoNow)

New-Item -ItemType Directory -Force -Path (Split-Path $progressFile -Parent) | Out-Null
($progress | ConvertTo-Json -Depth 50) | Set-Content -Path $progressFile -Encoding utf8NoBOM

Write-Host "Manifests built: wingless=$($wingless.Count) prewinged=$($prewinged.Count) wings=$($wings.Keys.Count) wallpapers=$count WPI=$wpi"
