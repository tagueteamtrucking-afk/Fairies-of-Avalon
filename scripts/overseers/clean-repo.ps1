param([string]$RepoRoot=".",[switch]$Apply)
$ErrorActionPreference='Stop'
$manifestPath = Join-Path $RepoRoot "repo-structure.json"
if(!(Test-Path $manifestPath)){ throw "repo-structure.json not found at $manifestPath" }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$allow = @($manifest.allowlist | ForEach-Object { (Join-Path $RepoRoot $_).Replace('\','/') })
$preserveGlobs = @($manifest.preserve_globs)

Write-Host "== DRY RUN ==" -ForegroundColor Yellow
if($Apply){ Write-Host "APPLY MODE" -ForegroundColor Red }

# Build preserve set
$preserved = New-Object System.Collections.Generic.HashSet[string]
foreach($a in $allow){ [void]$preserved.Add($a) }

# Expand globs
$all = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Force -File | Where-Object { $_.FullName -notmatch '/\.git/' } | Select-Object -ExpandProperty FullName
$all = $all | ForEach-Object { $_ -replace '\\','/' }

function MatchesGlob($path, $glob){
  $g = '^' + [Regex]::Escape($glob -replace '\*\*','__STARSTAR__' -replace '\*','__STAR__').Replace('__STARSTAR__','.*').Replace('__STAR__','[^/]*') + '$'
  return ($path -replace '\\','/') -match $g
}

foreach($g in $preserveGlobs){
  foreach($p in $all){
    if(MatchesGlob($p, (Join-Path $RepoRoot $g).Replace('\','/'))){ [void]$preserved.Add($p) }
  }
}

$toDelete = @()
foreach($p in $all){ if(!$preserved.Contains($p)){ $toDelete += $p } }

Write-Host "Files that would be deleted:" -ForegroundColor Yellow
$toDelete | ForEach-Object { Write-Host "  $_" }

if($Apply){
  foreach($f in $toDelete){
    try{ Remove-Item -LiteralPath $f -Force }catch{ Write-Warning "Failed to remove $f : $_" }
  }
  Write-Host "Cleanup applied."
}else{
  Write-Host "Dry run only. Re-run with -Apply to delete." -ForegroundColor Yellow
}
