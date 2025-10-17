param(
  [switch]$ApplyFixes
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Ensure-Dir($p){
  if(-not (Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null; return $true } else { return $false }
}

$report = @{
  updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
  created_dirs = @()
  warnings = @()
  actions = @()
}

# Expected structure
$dirs = @(
  "pages/apps/jem/programs","pages/apps/jem/intake","pages/apps/jem/logs","pages/apps/jem/imports",
  "pages/apps/carol/plans"
)
foreach($d in $dirs){
  $full = Join-Path $root $d
  if(Ensure-Dir $full){ $report.created_dirs += $d }
}

# Normalize Week1 names if needed
$normScript = Join-Path $root "scripts/Jem-Normalize-Week1.ps1"
if(Test-Path $normScript){
  try{
    pwsh -File $normScript -ProgramsDir "pages/apps/jem/programs" -MapFile "pages/apps/jem/programs/name-map.json"
    $report.actions += "Normalized week1 files (if needed)"
  } catch {
    $report.warnings += "Normalize script error: $($_.Exception.Message)"
  }
} else {
  $report.warnings += "Missing scripts/Jem-Normalize-Week1.ps1"
}

# Ensure programs/index.json exists
$progDir = Join-Path $root "pages/apps/jem/programs"
$idxPath = Join-Path $progDir "index.json"
if(-not (Test-Path $idxPath)){
  $files = Get-ChildItem -Path $progDir -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object { "programs/"+$_.Name }
  $idx = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$files }
  [IO.File]::WriteAllText($idxPath, ($idx | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
  $report.actions += "Created programs/index.json"
}

# Ensure carol plans index
$carolDir = Join-Path $root "pages/apps/carol/plans"
$carIdx = Join-Path $carolDir "index.json"
if(-not (Test-Path $carIdx)){
  $files = Get-ChildItem -Path $carolDir -Filter "*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if($files){
    $first = $files[0].Name
    $idx = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=@($first) }
    [IO.File]::WriteAllText($carIdx, ($idx | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
    $report.actions += "Created carol plans/index.json -> $first"
  } else {
    $report.warnings += "No plan JSONs found for Carol to index"
  }
}

# Detect stray version-busting redirects (?v=...)
$rootIndex = Join-Path $root "index.html"
if(Test-Path $rootIndex){
  $txt = Get-Content -Raw -Path $rootIndex
  if($txt -match '\?v=\d{8}[a-z]'){
    if($ApplyFixes){
      $new = $txt -replace '\?v=\d{8}[a-z]',''
      [IO.File]::WriteAllText($rootIndex, $new, [Text.Encoding]::UTF8)
      $report.actions += "Stripped ?v= cache bust from root index.html"
    } else {
      $report.warnings += "Found '?v=' pattern in root index.html (run with -ApplyFixes to strip)"
    }
  }
}

# Write diagnostics
$diag = Join-Path $root "pages/apps/overseers/repo-doctor-report.json"
if(-not (Test-Path (Split-Path -Parent $diag))){ New-Item -ItemType Directory -Force -Path (Split-Path -Parent $diag) | Out-Null }
[IO.File]::WriteAllText($diag, ($report | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Repo Doctor wrote report to $diag"
