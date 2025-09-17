param(
  [Parameter()][string]$RepoRoot = ".",
  [switch]$Apply
)
$ErrorActionPreference='Stop'
# Ensure YAML module for future use; not needed here
try { Import-Module powershell-yaml -ErrorAction Stop } catch { try { Install-Module powershell-yaml -Force -Scope CurrentUser -AllowClobber; Import-Module powershell-yaml } catch {} }

$manifestPath = Join-Path $RepoRoot "repo-structure.json"
if(!(Test-Path $manifestPath)){ throw "repo-structure.json not found at $manifestPath" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$allow = @($manifest.allowlist | ForEach-Object { (Join-Path $RepoRoot $_).Replace('\','/') })
$preserveGlobs = @($manifest.preserve_globs)

Write-Host "== DRY RUN MODE ==" -ForegroundColor Yellow
if($Apply){ Write-Host "APPLY MODE (files will be deleted)" -ForegroundColor Red }

# Build set of preserved items via globs
$preserved = New-Object System.Collections.Generic.HashSet[string]
foreach($g in $preserveGlobs){
  $paths = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -replace '\\','/' -like ($RepoRoot -replace '\\','/' + '/' + ($g -replace '\*\*','*'))
  } | Select-Object -ExpandProperty FullName
  foreach($p in $paths){ [void]$preserved.Add(($p -replace '\\','/')) }
}
# Always preserve the explicit allowlist
foreach($a in $allow){ [void]$preserved.Add($a) }

# Candidate files: all files under repo
$all = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Force -File | Select-Object -ExpandProperty FullName
$all = $all | ForEach-Object { $_ -replace '\\','/' }

# Exclusions: .git folder
$all = $all | Where-Object { $_ -notmatch '/\.git/' }

$toDelete = @()
foreach($f in $all){
  if($preserved.Contains($f)) { continue }
  # Additional preserve: keep everything under asset/models and asset/wings by default
  if($f -match '/asset/models/' -or $f -match '/asset/wings/') { continue }
  $toDelete += $f
}
Write-Host "Files that would be deleted:" -ForegroundColor Yellow
$toDelete | ForEach-Object { Write-Host "  $_" }

if($Apply){
  foreach($f in $toDelete){
    try { Remove-Item -LiteralPath $f -Force } catch { Write-Warning "Failed to remove $f : $_" }
  }
  Write-Host "Cleanup applied."
}else{
  Write-Host "Dry run only. Re-run with -Apply to delete." -ForegroundColor Yellow
}
