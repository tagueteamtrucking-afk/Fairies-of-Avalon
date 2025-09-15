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

function Read-YamlSafe([string]$path, [switch]$IsMemory){
  try {
    $raw = Get-Content -Raw -Path $path -ErrorAction Stop
    return ConvertFrom-Yaml -Yaml $raw -AllDocuments | Select-Object -First 1
  } catch {
    Write-Host "::warning:: YAML read failed at $path — attempting auto-restore..."
    if ($IsMemory) {
      & (Join-Path $PSScriptRoot "normalize-memory.ps1") -RepoRoot $RepoRoot -AutoRestore
      try {
        $raw2 = Get-Content -Raw -Path $path -ErrorAction Stop
        return ConvertFrom-Yaml -Yaml $raw2 -AllDocuments | Select-Object -First 1
      } catch {
        Write-Host "::error:: Memory still invalid after restore. Using minimal baseline in-memory."
        return @{ avatars_present = @("Abbey","Alexandria","Billie","Carol","Charlotte","Clarice","Jem","Nina","Odessa","Reyczar","Sorcha","Themis","WhiteStar","Tracy","Stella") }
      }
    } else {
      # Non-memory YAML — skip gracefully
      return $null
    }
  }
}

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
  $rec = @{ file=$file.Name; started=UtcIso $started; status="running" }

  try {
    $q = Read-YamlSafe $file.FullName
    if (-not $q) { $rec.status="skipped"; $rec.note="Unreadable YAML"; throw "skip" }
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
        $memOk = $true
        try { $null = Read-YamlSafe $src -IsMemory } catch { $memOk=$false }
        if (-not $memOk) { throw "Memory invalid — snapshot aborted" }
        $dstDir = Join-Path $RepoRoot "memory-history"
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        $dst = Join-Path $dstDir ("{0}-Codys-Memory.yaml" -f (Get-Date -Format 'yyyyMMddTHHmmssZ'))
        Copy-Item -Path $src -Destination $dst -Force
        $rec.status = "ok"
      }
      "scaffold_fairies_bundle" {
        $mem = Read-YamlSafe (Join-Path $RepoRoot "Cody's Memory.yaml") -IsMemory
        $avatars = @($q.params.avatars)
        if (-not $avatars -or $avatars.Count -eq 0) { $avatars = @($mem.avatars_present) }
        if (-not $avatars -or $avatars.Count -eq 0) { throw "No avatars found to scaffold." }

        $scaffoldDir = Join-Path $RepoRoot "pages/apps/overseers/scaffolds"
        New-Item -ItemType Directory -Force -Path $scaffoldDir | Out-Null

        $dryRun = $true
        if (($env:OPENAI_API_KEY -or $env:ANTHROPIC_API_KEY) -and ($q.dry_run -eq $false)) { $dryRun = $false }
        $rec.dry_run = $dryRun

        $countOK = 0
        foreach ($name in $avatars) {
          $prompt = "Generate a minimal scaffold plan for Avalon Fairy '$name'..."
          $outFile = Join-Path $scaffoldDir ("{0}.plan.txt" -f ($name.ToString().ToLowerInvariant()))
          & (Join-Path $PSScriptRoot "llm-bridge.ps1") -Prompt $prompt -OutFile $outFile -DryRun:($dryRun)
          if (Test-Path $outFile) { $countOK++ }
        }
        $rec.count = $avatars.Count
        $rec.written = $countOK
        $rec.status = "ok"
      }
      "create_microapps" {
        & (Join-Path $PSScriptRoot "create-microapps.ps1") -RepoRoot $RepoRoot -Avatars @($q.params.avatars)
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
        $rec.status = "skipped"; $rec.note = "Unknown action '$($q.action)'"
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
    if ("skip" -ne $_) {
      $rec.status = "failed"; $rec.error  = ($_ | Out-String); $rec.ended  = UtcIso (UtcNow)
      $progress.processed += $rec; $progress.totals.failed++
      Move-Item -Path $file.FullName -Destination (Join-Path $ProcessedDir $file.Name) -Force
    }
  }
}

$progress.pending = (Get-ChildItem $RequestsDir -File | Measure-Object).Count
New-Item -ItemType Directory -Force -Path (Split-Path $ProgressFile -Parent) | Out-Null
Write-Json $progress $ProgressFile

Write-Host ("::notice title=Overseers Queue::{0} ok, {1} failed, {2} skipped; Pending {3}" -f `
  $progress.totals.success, $progress.totals.failed, $progress.totals.skipped, $progress.pending)

exit 0
