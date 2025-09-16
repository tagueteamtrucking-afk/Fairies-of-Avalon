[CmdletBinding()]
param(
  [string]$RepoRoot="."
)
$ErrorActionPreference='Stop'
function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
$root = (Resolve-Path $RepoRoot).Path
$worlds = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worlds)) { throw "Worlds dir not found: $worlds" }

$exportsDir = Join-Path $worlds "exports"
New-Item -ItemType Directory -Force -Path $exportsDir | Out-Null
$stamp = (Get-Date -Format 'yyyyMMddHHmmss')
$zip = Join-Path $exportsDir ("worldbundle-" + $stamp + ".zip")

# Build a temp staging directory
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("alexandria_worldbundle_" + $stamp)
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# Copy JSON trees (seed/bible/timelines/codex/atlas) + choices + taxonomies
$copyList = @(
  "pages/apps/alexandria/worlds",
  "pages/apps/alexandria/knowledge/choices.json",
  "pages/apps/alexandria/knowledge/atlas-taxonomy.json",
  "pages/apps/alexandria/knowledge/npc-taxonomy.json",
  "pages/apps/alexandria/knowledge/bible-taxonomy.json",
  "pages/apps/alexandria/knowledge/timeline-taxonomy.json"
)
foreach($item in $copyList){
  $src = Join-Path $RepoRoot $item
  if (Test-Path $src){
    $dst = Join-Path $tmp $item
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item -Recurse -Force -Path $src -Destination $dst
  }
}

if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $tmp "*") -DestinationPath $zip

# Update exports index
$indexPath = Join-Path $exportsDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
$rel = "/apps/alexandria/worlds/exports/" + (Split-Path $zip -Leaf)
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; size=(Get-Item $zip).Length; ts=(Iso) }
($index | ConvertTo-Json -Depth 100) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "WorldBundle created: $rel"
exit 0
