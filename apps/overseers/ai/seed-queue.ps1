# Overseers Queue Seeder — reads Memory and enqueues tasks for all Fairies.
[CmdletBinding()]param(
  [switch]$IncludeWingsManifest
)
$ErrorActionPreference = 'Stop'

function Ensure-YamlModule {
  if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) { return }
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
  if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
  }
  Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop | Out-Null
  Import-Module powershell-yaml -Force -ErrorAction Stop
}

$Root  = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Queue = Join-Path $Root 'apps\overseers\queue'
New-Item -ItemType Directory -Force -Path $Queue | Out-Null

Ensure-YamlModule
$memPath = Join-Path $Root "Cody's Memory.yaml"
$mem = ConvertFrom-Yaml -Yaml (Get-Content -Raw -LiteralPath $memPath -Encoding UTF8)

$ids = $mem.build_order_initial
if (-not $ids) { throw "No build_order_initial in Memory." }

$i = 1
foreach ($id in $ids) {
  $task = @{
    id       = "scaffold:$id"
    type     = "scaffold_fairy"
    fairy_id = "$id"
    created  = (Get-Date).ToString('s') + 'Z'
    status   = "queued"
  } | ConvertTo-Json -Depth 6
  $file = ("{0:D3}_{1}.json" -f $i, $id)
  Set-Content -LiteralPath (Join-Path $Queue $file) -Encoding UTF8 -NoNewline -Value $task
  $i++
}

# Always refresh models manifest
$mf1 = @{ id="write_models_manifest"; type="write_models_manifest"; created=(Get-Date).ToString('s')+'Z'; status="queued" } | ConvertTo-Json -Depth 6
Set-Content -LiteralPath (Join-Path $Queue ('{0:D3}_models_manifest.json' -f $i)) -Encoding UTF8 -NoNewline -Value $mf1

if ($IncludeWingsManifest) {
  $mf2 = @{ id="write_wings_manifest"; type="write_wings_manifest"; created=(Get-Date).ToString('s')+'Z'; status="queued" } | ConvertTo-Json -Depth 6
  Set-Content -LiteralPath (Join-Path $Queue ('{0:D3}_wings_manifest.json' -f ($i+1))) -Encoding UTF8 -NoNewline -Value $mf2
}

Write-Host "Queued $($ids.Count) scaffold task(s) + models manifest."
exit 0
