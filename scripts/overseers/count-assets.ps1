[CmdletBinding()]
param([switch]$WriteProgressJson = $true)

$ErrorActionPreference = 'Stop'

function Ensure-YamlModule {
  try {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
      Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module powershell-yaml -ErrorAction Stop | Out-Null
  } catch { Write-Warning "YAML module unavailable; continuing without Memory parsing." }
}

function Read-Memory($Path) {
  if (Test-Path -LiteralPath $Path) {
    try { (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Yaml } catch { $null }
  }
}

function Count-Files([string]$Path,[string[]]$Include,[switch]$Recurse) {
  if (-not (Test-Path -LiteralPath $Path)) { return @{ Count=0; Size=0 } }
  $opt = @{ File=$true; ErrorAction='SilentlyContinue' }
  if ($Recurse) { $opt.Recurse = $true }
  $items = Get-ChildItem -LiteralPath $Path -Include $Include @opt
  @{ Count = ($items | Measure-Object).Count; Size = ($items | Measure-Object Length -Sum).Sum }
}

function Get-WingGroups([System.IO.FileInfo[]]$Files) {
  $rx = [regex]'wing(?<n>\d+)'
  $groups = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($f in $Files) { $m = $rx.Match($f.Name.ToLower()); if ($m.Success){ [void]$groups.Add($m.Groups['n'].Value) } }
  $groups
}

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$memoryPath = Join-Path $repoRoot "Cody's Memory.yaml"

Ensure-YamlModule
$mem = Read-Memory $memoryPath

# Resolve paths (with fallbacks)
$modelsRootLegacy = $mem.assets.layout.models_root_legacy; if (-not $modelsRootLegacy){$modelsRootLegacy="asset/models"}
$winglessPath     = $mem.assets.layout.wingless_vrms
$withWingsPath    = $mem.assets.layout.with_wings_vrms
$withWingsAlias   = $mem.assets.layout.with_wings_alias; if (-not $withWingsAlias){$withWingsAlias="asset/winged-models"}
$wingsModelsPath  = $mem.assets.layout.wings_models;     if (-not $wingsModelsPath){$wingsModelsPath="asset/wings"}
$wingsTexPath     = $mem.assets.layout.wings_textures;   if (-not $wingsTexPath){$wingsTexPath="asset/wings/textures"}
$wallsPath        = $mem.assets.layout.wallpapers;       if (-not $wallsPath){$wallsPath="asset/textures/wallpapers"}

function F($p){ Join-Path $repoRoot $p }

# Wingless from legacy root (filter *_wings/-wings)
$legacyFiles = @()
if (Test-Path (F $modelsRootLegacy)) {
  $legacyFiles = Get-ChildItem -LiteralPath (F $modelsRootLegacy) -Filter *.vrm -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.BaseName -notmatch '(_wings|-wings)$' }
}
$winglessCount = $legacyFiles.Count
$winglessBytes = ($legacyFiles | Measure-Object Length -Sum).Sum

foreach($p in @($winglessPath)){
  if ($p -and (Test-Path (F $p))){
    $c = Count-Files (F $p) @('*.vrm')
    $winglessCount += $c.Count; $winglessBytes += $c.Size
  }
}

# With-wings
$withWingsCount=0; $withWingsBytes=0
foreach($p in @($withWingsPath,$withWingsAlias)){
  if ($p -and (Test-Path (F $p))){
    $c = Count-Files (F $p) @('*.vrm')
    $withWingsCount += $c.Count; $withWingsBytes += $c.Size
  }
}

# Wings meshes/textures
$mesh = Count-Files (F $wingsModelsPath) @('*.fbx','*.glb','*.gltf')
$tex  = Count-Files (F $wingsTexPath)    @('*.png','*.jpg','*.jpeg') -Recurse
$walls= Count-Files (F $wallsPath)       @('*.png','*.jpg','*.jpeg')

$meshFiles = @(); if (Test-Path (F $wingsModelsPath)){ $meshFiles = Get-ChildItem -LiteralPath (F $wingsModelsPath) -File -Include *.fbx,*.glb,*.gltf }
$texFiles  = @(); if (Test-Path (F $wingsTexPath)){    $texFiles  = Get-ChildItem -LiteralPath (F $wingsTexPath)    -File -Include *.png,*.jpg,*.jpeg -Recurse }

$meshGroups = Get-WingGroups $meshFiles
$texGroups  = Get-WingGroups $texFiles

$union     = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Distinct($meshGroups + $texGroups))
$intersect = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Intersect($meshGroups,$texGroups))
$missingM  = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Except($texGroups,$meshGroups))
$missingT  = [System.Linq.Enumerable]::ToArray([System.Linq.Enumerable]::Except($meshGroups,$texGroups))

function MB($b){ [Math]::Round(($b/1MB),2) }

$budgets = @{}
if ($mem -and $mem.assets -and $mem.assets.budgets) { $budgets = $mem.assets.budgets } else {
  $budgets = @{ initial_shell_kb=300; initial_requests=15; vrm_per_file_mb=40; wallpapers_total=20 }
}

$result = [ordered]@{
  ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  paths = @{
    models_root_legacy = $modelsRootLegacy
    wingless_vrms      = $winglessPath
    with_wings_vrms    = $withWingsPath
    with_wings_alias   = $withWingsAlias
    wings_models       = $wingsModelsPath
    wings_textures     = $wingsTexPath
    wallpapers         = $wallsPath
  }
  assets = @{
    vrm_wingless   = @{ count=$winglessCount;   size_mb= (MB $winglessBytes) }
    vrm_with_wings = @{ count=$withWingsCount;  size_mb= (MB $withWingsBytes) }
    wings_meshes   = @{ count=$mesh.Count;      size_mb= (MB $mesh.Size) }
    wings_textures = @{ count=$tex.Count;       size_mb= (MB $tex.Size) }
    wallpapers     = @{ count=$walls.Count;     size_mb= (MB $walls.Size) }
    coverage       = @{
      groups_total                  = $union.Count
      groups_with_mesh_and_textures = $intersect.Count
      groups_missing_mesh           = $missingM
      groups_missing_textures       = $missingT
    }
  }
  budgets = $budgets
  notes = @("Counts include alias path asset/winged-models.","Budgets are soft; optimize shell weight and lazy-loading.")
}

if ($WriteProgressJson) {
  $outDir = Join-Path $repoRoot "pages/apps/overseers"
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
  $outPath = Join-Path $outDir "progress.json"
  $result | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $outPath -Encoding UTF8
  Write-Host "Wrote $outPath"
}

"{0} | VRMs: {1} wingless, {2} pre-winged | Wings: {3} meshes, {4} textures | Groups {5}/{6} covered" -f `
  $result.ts, $winglessCount, $withWingsCount, $mesh.Count, $tex.Count, $intersect.Count, $union.Count
