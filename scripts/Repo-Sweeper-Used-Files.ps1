param(
  [string]$KeepListFile="config/keep-lists/workflows-keep.json",
  [switch]$Delete,
  [switch]$Archive,
  [switch]$VerboseLog
)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$wfDir = Join-Path $root ".github/workflows"

if(-not (Test-Path $wfDir)){ Write-Error "No .github/workflows directory found"; exit 1 }
try{ $keep = Get-Content -Raw -Path (Join-Path $root $KeepListFile) | ConvertFrom-Json } catch { $keep = @{ workflows=@() } }
$keepNames = @($keep.workflows)

# Build refs first
pwsh -File (Join-Path $root "scripts/Repo-Inventory.ps1") | Out-Null
pwsh -File (Join-Path $root "scripts/Repo-Refs-Graph.ps1") | Out-Null

# Usage report (no archive here)
pwsh -File (Join-Path $root "scripts/Repo-Usage-Report.ps1") | Out-Null

# For workflows: remove anything not in keep list (when -Delete)
$all = Get-ChildItem -Path $wfDir -File -Include *.yml,*.yaml -Recurse
$toDelete = @()
foreach($f in $all){ if($keepNames -and ($keepNames -notcontains $f.Name)){ $toDelete += $f.FullName } }
if($VerboseLog){ Write-Host "Workflows to delete: $($toDelete.Count)" }
if($Delete){ foreach($p in $toDelete){ Remove-Item -Path $p -Force; if($VerboseLog){ Write-Host "Deleted $p" } } }

# For scripts: archive orphans (never delete here)
pwsh -File (Join-Path $root "scripts/Repo-Usage-Report.ps1") -ArchiveOrphans:$Archive | Out-Null
Write-Host "Sweep complete. See memory-history/*.json for reports."
