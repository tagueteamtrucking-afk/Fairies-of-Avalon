# Requires: helpers.ps1
. "$PSScriptRoot\helpers.ps1"
Ensure-YamlModule

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

# 1) Read requests/grants
$requests = Read-YamlFiles "permissions\Requests\*.yml"
$requests += Read-YamlFiles "permissions\Requests\*.yaml"

$grants   = Read-YamlFiles "permissions\Grants\*.yml"
$grants  += Read-YamlFiles "permissions\Grants\*.yaml"

# 2) Normalize/sort
function Normalize-Request($r) {
  [pscustomobject]@{
    id            = $r.id
    requester     = $r.requester
    scopes        = @($r.scopes)
    justification = $r.justification
    requestedAt   = $r.requestedAt
    status        = ($r.status | ForEach-Object { $_ })  # e.g., requested, approved, denied
  }
}
function Normalize-Grant($g) {
  [pscustomobject]@{
    id            = $g.id
    requestId     = $g.requestId
    overseer      = $g.overseer
    result        = $g.result     # approved | denied
    grantedScopes = @($g.grantedScopes)
    expires       = $g.expires
    grantedAt     = $g.grantedAt
  }
}

$reqs = @()
foreach ($r in $requests) { $reqs += (Normalize-Request $r) }
$grts = @()
foreach ($g in $grants) { $grts += (Normalize-Grant $g) }

# 3) Build state object
$state = [pscustomobject]@{
  lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  requests    = $reqs
  grants      = $grts
}

# 4) Write to pages/apps/overseers/permissions/state.json
$outPath = "pages\apps\overseers\permissions\state.json"
Write-Json -Data $state -Path $outPath

# 5) Move processed files to permissions/processed/
$processedDir = "permissions\processed"
if (-not (Test-Path $processedDir)) { New-Item -ItemType Directory -Path $processedDir | Out-Null }
function Archive-Files($files) {
  foreach ($f in $files) {
    try {
      $name = Split-Path -Leaf $f.sourceFile
      $stamp = Get-Date -UFormat "%Y%m%dT%H%M%SZ"
      $dest = Join-Path $processedDir "$stamp-$name"
      Move-Item -Path $f.sourceFile -Destination $dest -Force
    } catch {
      # If move fails (e.g., race), skip
    }
  }
}
Archive-Files $requests
Archive-Files $grants

Write-Host "Permissions processing complete."
