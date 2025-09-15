[CmdletBinding()]
param(
  [string]$RepoRoot = ".",
  [int]$MaxItems = 100
)

$ErrorActionPreference = 'Stop'

try { Import-Module powershell-yaml -ErrorAction Stop }
catch {
  Write-Host "::warning::powershell-yaml not loaded; attempting install..."
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function Read-Yaml([string]$path) { (Get-Content -Raw -Path $path) | ConvertFrom-Yaml }
function Write-Json([object]$obj, [string]$path) {
  $json = $obj | ConvertTo-Json -Depth 20
  Set-Content -Path $path -Value $json -Encoding utf8NoBOM
}
function UtcNow(){ (Get-Date).ToUniversalTime() }
function UtcIso([datetime]$d){ $d.ToString("o") }

$RequestsDir  = Join-Path $RepoRoot "requests"
$ProcessedDir = Join-Path $RepoRoot "processed"
$ProgressFile = Join-Path $RepoRoot "pages/apps/overseers/progress.json"

New-Item -ItemType Directory -Force -Path $RequestsDir, $ProcessedDir | Out-Null

$pending = Get-ChildItem $RequestsDir -File | Where-Object { $_.Extension -match 'ya?ml' } | Sort-Object Name | Select-Object -First $MaxItems
$progress = @{
  last_run = UtcIso (UtcNow)
  totals   = @{ success = 0; failed = 0; skipped = 0 }
  pending  = (Get-ChildItem $RequestsDir -File | Measure-Object).Count
  processed = @()
}

foreach ($file in $pending) {
  $started = UtcNow
  $rec = @{
    file    = $file.Name
    started = UtcIso $started
    status  = "running"
  }

  try {
    $q = Read-Yaml $file.FullName
    $rec.id     = $q.id
    $rec.action = $q.action
    $rec.actor  = $q.actor
    $rec.ts     = $q.ts
    if ($null -ne $q.dry_run) { $rec.dry_run = [bool]$q.dry_run }

    switch ($q.action) {

      "asset_audit" {
        & (Join-Path $PSScriptRoot "count-assets.ps1") -RepoRoot $RepoRoot
        $rec.status = "ok"
      }

      "importmap_check" {
        & (Join-Path $PSScriptRoot "validate-importmap.ps1") -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { throw "Import-map check exit code: $LASTEXITCODE" }
        $rec.status = "ok"
      }

      "memory_snapshot" {
        $src = Join-Path $RepoRoot "Cody's Memory.yaml"
        if (!(Test-Path $src)) { throw "Memory file not found at $src" }
        $dstDir = Join-Path $RepoRoot "memory-history"
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        $dst = Join-Path $dstDir ("{0}-Codys-Memory.yaml" -f (Get-Date -Format 'yyyyMMddTHHmmssZ'))
        Copy-Item -Path $src -Destination $dst -Force
        $rec.status = "ok"
      }

      "scaffold_fairies_bundle" {
        $avatars = @()
        if ($q.params -and $q.params.avatars) { $avatars = @($q.params.avatars) }
        if (-not $avatars -or $avatars.Count -eq 0) {
          $mem = (Get-Content -Raw -Path (Join-Path $RepoRoot "Cody's Memory.yaml")) | ConvertFrom-Yaml
          $avatars = @($mem.avatars_present)
        }
        if (-not $avatars -or $avatars.Count -eq 0) { throw "No avatars found to scaffold." }

        $scaffoldDir = Join-Path $RepoRoot "pages/apps/overseers/scaffolds"
        New-Item -ItemType Directory -Force -Path $scaffoldDir | Out-Null

        $dryRun = $true
        if (($env:OPENAI_API_KEY -or $env:ANTHROPIC_API_KEY) -and ($q.dry_run -eq $false)) { $dryRun = $false }
        $rec.dry_run = $dryRun
        $countOK = 0

        foreach ($name in $avatars) {
          $prompt = @"
Generate a minimal, actionable scaffold plan to build the Avalon Fairy assistant named '$name'.

Constraints:
- GitHub Pages PWA shell; workflows-first; no plaintext secrets.
- Import map required when modules used ('three','three/addons/','@pixiv/three-vrm').
- Asset layout: asset/models, asset/winged-models, asset/wings(+textures).
- Map steps to queueable actions.

Deliver (plaintext, <= 250 lines):
1) Checklist (file/workflow per item).
2) File inventory (paths only).
3) GitHub Actions jobs: names+triggers+purpose.
"@
          $outFile = Join-Path $scaffoldDir ("{0}.plan.txt" -f ($name.ToString().ToLowerInvariant()))
          & (Join-Path $PSScriptRoot "llm-bridge.ps1") -Prompt $prompt -OutFile $outFile -DryRun:($dryRun)
          if (Test-Path $outFile) { $countOK++ }
        }
        $rec.count = $avatars.Count
        $rec.written = $countOK
        $rec.status = "ok"
      }

      "create_microapps" {
        $avatars = @()
        if ($q.params -and $q.params.avatars) { $avatars = @($q.params.avatars) }
        & (Join-Path $PSScriptRoot "create-microapps.ps1") -RepoRoot $RepoRoot -Avatars $avatars
        $rec.status = "ok"
      }

      "build_manifests" {
        & (Join-Path $PSScriptRoot "build-manifests.ps1") -RepoRoot $RepoRoot
        $rec.status = "ok"
      }

      "permissions_process" {
        & (Join-Path $PSScriptRoot "process-permissions.ps1") -RepoRoot $RepoRoot
        $rec.status = "ok"
      }

      default {
        $rec.status = "skipped"
        $rec.note   = "Unknown action '$($q.action)'"
      }
    }

    $rec.ended = UtcIso (UtcNow)
    $progress.processed += $rec

    if     ($rec.status -eq "ok")      { $progress.totals.success++ }
    elseif ($rec.status -eq "skipped") { $progress.totals.skipped++ }
    else                                { $progress.totals.failed++ }

    Move-Item -Path $file.FullName -Destination (Join-Path $ProcessedDir $file.Name) -Force
  }
  catch {
    $rec.status = "failed"
    $rec.error  = ($_ | Out-String)
    $rec.ended  = UtcIso (UtcNow)
    $progress.processed += $rec
    $progress.totals.failed++
    Move-Item -Path $file.FullName -Destination (Join-Path $ProcessedDir $file.Name) -Force
  }
}

$progress.pending = (Get-ChildItem $RequestsDir -File | Measure-Object).Count
New-Item -ItemType Directory -Force -Path (Split-Path $ProgressFile -Parent) | Out-Null
Write-Json $progress $ProgressFile

Write-Host ("::notice title=Overseers Queue::{0} ok, {1} failed, {2} skipped; Pending {3}" -f `
  $progress.totals.success, $progress.totals.failed, $progress.totals.skipped, $progress.pending)

exit 0
