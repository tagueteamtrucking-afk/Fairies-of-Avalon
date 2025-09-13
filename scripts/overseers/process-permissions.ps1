# Builds BOTH: permissions state.json and overseers progress.json
. "$PSScriptRoot\helpers.ps1"
Ensure-YamlModule

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

# ---------- 1) Read permission requests/grants ----------
$requests = @()
$requests += Read-YamlFiles "permissions\Requests\*.yml"
$requests += Read-YamlFiles "permissions\Requests\*.yaml"
$requests += Read-YamlFiles "permissions\requests\*.yml"
$requests += Read-YamlFiles "permissions\requests\*.yaml"

$grants = @()
$grants += Read-YamlFiles "permissions\Grants\*.yml"
$grants += Read-YamlFiles "permissions\Grants\*.yaml"
$grants += Read-YamlFiles "permissions\grants\*.yml"
$grants += Read-YamlFiles "permissions\grants\*.yaml"

function Normalize-Request($r) {
  [pscustomobject]@{
    id            = $r.id
    requester     = $r.requester
    scopes        = @($r.scopes)
    justification = $r.justification
    requestedAt   = $r.requestedAt
    status        = ($r.status | ForEach-Object { $_ })
  }
}
function Normalize-Grant($g) {
  [pscustomobject]@{
    id            = $g.id
    requestId     = $g.requestId
    overseer      = $g.overseer
    result        = $g.result
    grantedScopes = @($g.grantedScopes)
    expires       = $g.expires
    grantedAt     = $g.grantedAt
  }
}

$reqs = @(); foreach ($r in $requests) { $reqs += (Normalize-Request $r) }
$grts = @(); foreach ($g in $grants)   { $grts += (Normalize-Grant   $g) }

$state = [pscustomobject]@{
  lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  requests    = $reqs
  grants      = $grts
}

Write-Json -Data $state -Path "pages\apps\overseers\permissions\state.json"

# Archive processed files to permissions/processed/
$processedDir = "permissions\processed"
if (-not (Test-Path $processedDir)) { New-Item -ItemType Directory -Path $processedDir | Out-Null }
function Archive-Files($files) {
  foreach ($f in $files) {
    try {
      $name = Split-Path -Leaf $f.sourceFile
      $stamp = Get-Date -UFormat "%Y%m%dT%H%M%SZ"
      $dest = Join-Path $processedDir "$stamp-$name"
      if (Test-Path $f.sourceFile) { Move-Item -Path $f.sourceFile -Destination $dest -Force }
    } catch { }
  }
}
Archive-Files $requests
Archive-Files $grants

# ---------- 2) Build Overseers progress.json ----------
function Has([string]$p) { return Test-Path $p -PathType Leaf -ErrorAction SilentlyContinue }
function HasDir([string]$p){ return Test-Path $p -PathType Container -ErrorAction SilentlyContinue }

$pwaShell     = (Has "pages\index.html") -and (Has "pages\app.css") -and (Has "pages\sw.js") -and (Has "pages\manifest.webmanifest")
$consoleFiles = (Has "pages\apps\overseers\console.html") -and (Has "pages\apps\overseers\console.js")
$stateFile    = Has "pages\apps\overseers\permissions\state.json"
$workflowAI   = Has ".github\workflows\overseers-ai-core.yml"
$scriptsOK    = (Has "scripts\overseers\helpers.ps1") -and (Has "scripts\overseers\process-permissions.ps1")
$cnameOK      = Has "CNAME"
$nojekyllOK   = Has ".nojekyll"
$capabilities = Has "pages\apps\overseers\capabilities.json"

$wallpapersCt = 0
if (HasDir "asset\textures\wallpapers") {
  $wallpapersCt = (Get-ChildItem "asset\textures\wallpapers" -Include *.png,*.jpg,*.jpeg,*.webp -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
}

$importPins = $false
if (Has "pages\index.html") {
  $html = Get-Content "pages\index.html" -Raw
  if ($html -match "three@0\.177\.0" -and $html -match "@pixiv/three-vrm@3\.4\.2") { $importPins = $true }
}

$reqCt = (Get-ChildItem "permissions\requests" -Include *.yml,*.yaml -ErrorAction SilentlyContinue | Measure-Object).Count
$grtCt = (Get-ChildItem "permissions\grants"   -Include *.yml,*.yaml -ErrorAction SilentlyContinue | Measure-Object).Count

# VRMs present (wingless + winged)
$vrmWingless = 0
if (HasDir "asset\models") {
  $vrmWingless = (Get-ChildItem "asset\models" -Filter *.vrm -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
}
$vrmWinged = 0
if (HasDir "asset\winged-models") {
  $vrmWinged = (Get-ChildItem "asset\winged-models" -Filter *.vrm -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
}
$vrmPresent = $vrmWingless + $vrmWinged

# VRMs expected from Memory.yaml (fallback 15)
$vrmExpected = $null
try {
  $memRaw = Get-Content "Cody's Memory.yaml" -Raw -ErrorAction Stop
  $memObj = ConvertFrom-Yaml -Yaml $memRaw
  if ($memObj.assets.avatars_present) { $vrmExpected = $memObj.assets.avatars_present.Count }
} catch { }
if (-not $vrmExpected) { $vrmExpected = 15 }

$wingsMeshes   = (Get-ChildItem "asset\wings" -Filter *.fbx -ErrorAction SilentlyContinue | Measure-Object).Count
$wingsTextures = (Get-ChildItem "asset\wings\textures" -Include *.png,*.jpg,*.jpeg,*.webp -ErrorAction SilentlyContinue | Measure-Object).Count

# LLM readiness checks
$llmMissing = @()
# 1) Vault refs in Memory (tokens/passwords/permissions)
$memHasVaults = $false
try {
  if ($memObj -and $memObj.access_control.vault_references.tokens -and $memObj.access_control.vault_references.permissions) { $memHasVaults = $true }
} catch { }
if (-not $memHasVaults) { $llmMissing += "vault_refs" }
# 2) At least one approved grant allowing LLM invocation
$llmGrant = $false
foreach ($g in $grts) {
  if ($g.result -eq "approved") {
    foreach ($s in $g.grantedScopes) {
      if ($s -match "^llm\.invoke$" -or $s -match "^openai\.invoke$" -or $s -match "^anthropic\.invoke$") { $llmGrant = $true; break }
    }
  }
  if ($llmGrant) { break }
}
if (-not $llmGrant) { $llmMissing += "grant_llm_invoke" }
# 3) LLM bridge workflow present (scaffold ok)
$llmBridge = Test-Path ".github\workflows\llm-bridge.yml"
if (-not $llmBridge) { $llmMissing += "llm_bridge_workflow" }

$llmReady = ($llmMissing.Count -eq 0)

# --------- Scoring (weights sum to 100) ----------
$points = 0
function P([bool]$ok, [int]$w) { if ($ok) { return $w } else { return 0 } }

$points += P $pwaShell      12
$points += P $importPins     8
$points += P $consoleFiles  10

$stateOk = $false
if ($stateFile) {
  try {
    $s = Get-Content "pages\apps\overseers\permissions\state.json" -Raw | ConvertFrom-Json
    if ($s.lastUpdated -and $s.lastUpdated -ne "never") { $stateOk = $true }
  } catch { }
}
$points += P $stateOk       10
$points += P $workflowAI    10
$points += P $scriptsOK     10
$points += P ($cnameOK -and $nojekyllOK) 8
$points += P $capabilities   4
$points += P (($reqCt -ge 1) -or ($grtCt -ge 1)) 4

# VRM fraction up to 12 points (wingless + winged count towards presence)
$vrmFrac = 0.0
if ($vrmExpected -gt 0) { $vrmFrac = [Math]::Min(1.0, $vrmPresent / $vrmExpected) }
$points += [int][Math]::Round(12 * $vrmFrac)

# Wings & wallpapers
$points += P ($wingsMeshes   -ge 1) 4
$points += P ($wingsTextures -ge 1) 3
$points += P ($wallpapersCt  -ge 1) 5

$overall = [Math]::Min(100, $points)

# Category breakdowns
$foundationPoints = 0
$foundationPoints += P $pwaShell 12
$foundationPoints += P $importPins 8
$foundationPoints += P ($cnameOK -and $nojekyllOK) 8
$foundationPoints += P ($wallpapersCt -ge 1) 5
$foundationMax = 12+8+8+5
$foundationScore = [int][Math]::Round(100.0 * $foundationPoints / $foundationMax)

$overseersPoints = 0
$overseersPoints += P $consoleFiles 10
$overseersPoints += P $stateOk 10
$overseersPoints += P $workflowAI 10
$overseersPoints += P $scriptsOK 10
$overseersPoints += P $capabilities 4
$overseersPoints += P (($reqCt -ge 1) -or ($grtCt -ge 1)) 4
$overseersMax = 10+10+10+10+4+4
$overseersScore = [int][Math]::Round(100.0 * $overseersPoints / $overseersMax)

$assetsPoints = 0
$assetsPoints += [int][Math]::Round(12 * $vrmFrac)
$assetsPoints += P ($wingsMeshes   -ge 1) 4
$assetsPoints += P ($wingsTextures -ge 1) 3
$assetsMax = 12+4+3
$assetsScore = [int][Math]::Round(100.0 * $assetsPoints / $assetsMax)

$progress = [pscustomobject]@{
  lastUpdated = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  overall     = $overall
  categories  = @(
    @{ id = "foundation"; label = "Foundation (site + domain)"; score = $foundationScore; weight = 0.35 },
    @{ id = "overseers";  label = "Overseers Core (tools + queue)"; score = $overseersScore; weight = 0.45 },
    @{ id = "assets";     label = "Assets (VRMs + wings)"; score = $assetsScore; weight = 0.20 }
  )
  metrics = @{
    pwa_shell = $pwaShell
    importmap_pinned = $importPins
    console_present = $consoleFiles
    state_present = $stateFile
    state_ok = $stateOk
    ai_core_workflow = $workflowAI
    scripts_present = $scriptsOK
    cname = $cnameOK
    nojekyll = $nojekyllOK
    capabilities_present = $capabilities
    requests = $reqCt
    grants = $grtCt
    vrm_expected = $vrmExpected
    vrm_present = $vrmPresent
    vrm_wingless = $vrmWingless
    vrm_winged = $vrmWinged
    wings_meshes = $wingsMeshes
    wings_textures = $wingsTextures
    wallpapers = $wallpapersCt
    llm_ready = $llmReady
    llm_missing = $llmMissing
    llm_bridge_workflow = $llmBridge
  }
  notes = @(
    "This measures Memory + Tools readiness. Brains (LLM connectors) go green once vault refs + grant + bridge exist."
  )
}

Write-Json -Data $progress -Path "pages\apps\overseers\progress.json"

Write-Host "Permissions + Progress processing complete."
