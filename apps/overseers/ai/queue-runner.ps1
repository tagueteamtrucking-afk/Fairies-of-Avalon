# Overseers Queue Runner
# Reads apps/overseers/queue/*.json tasks, performs actions, and moves them to apps/overseers/log/.
# Requires PowerShell 7+ (pwsh). Uses ConvertFrom-Yaml built-in to parse Memory.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-ProjectRoot { return (Resolve-Path "$PSScriptRoot\..\..\..").Path }

$Root     = Get-ProjectRoot
$QueueDir = Join-Path $Root 'apps\overseers\queue'
$LogDir   = Join-Path $Root 'apps\overseers\log'
$OutDir   = Join-Path $Root 'apps\overseers\out'
New-Item -ItemType Directory -Force -Path $QueueDir,$LogDir,$OutDir | Out-Null

# ---- Memory ---------------------------------------------------------------
$MemoryPath = Join-Path $Root "Cody's Memory.yaml"
if (-not (Test-Path $MemoryPath)) {
  throw "Memory file not found: $MemoryPath"
}
$MEM = Get-Content -Raw -LiteralPath $MemoryPath -Encoding UTF8 | ConvertFrom-Yaml

$FAIRIES    = @{}
foreach ($f in $MEM.entities.fairies) { $FAIRIES[$f.id] = $f }
$INTERFACES = $MEM.interfaces_registry

# ---- Helpers --------------------------------------------------------------
function HtmlEscape([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '&','&amp;'
  $s = $s -replace '<','&lt;'
  $s = $s -replace '>','&gt;'
  $s = $s -replace '"','&quot;'
  return $s
}

function Ensure-Dir([string]$path) {
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}

function Write-Text([string]$path,[string]$content) {
  Ensure-Dir (Split-Path $path)
  Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline -Value $content
}

function Ensure-InterfaceStub([string]$id) {
  $iface = $INTERFACES."$id"
  if ($null -eq $iface) { return }
  $dir = Join-Path $Root 'pages\interfaces'
  Ensure-Dir $dir
  $path = Join-Path $dir "$id.html"
  if (Test-Path $path) { return }

  $html = @"
<!doctype html><html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>$id • Interface</title>
<style>
body{margin:0;background:#0b0b0b;color:#eee;font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif}
header{padding:14px 16px;border-bottom:1px solid #222}
main{max-width:1100px;margin:0 auto;padding:16px}
.card{border:1px solid #222;border-radius:10px;padding:16px;background:#121212;margin:16px 0}
a{color:#cde3ff}
</style></head><body>
<header><a href="/" style="color:#cde3ff;text-decoration:none">← Home</a></header>
<main>
  <div class="card">
    <h2 style="margin:0">$id</h2>
    <p><strong>Owner:</strong> $(HtmlEscape $iface.owner)</p>
    <p>$(HtmlEscape $iface.purpose)</p>
    <p>This is a placeholder micro‑app. The owning Fairy will expand this.</p>
  </div>
</main>
</body></html>
"@
  Write-Text -path $path -content $html
}

function Scaffold-Fairy([string]$id) {
  if (-not $FAIRIES.ContainsKey($id)) {
    Write-Warning "Fairy '$id' not found in Memory."
    return $false
  }
  $f = $FAIRIES[$id]
  $dir = Join-Path $Root "pages\fairies\$id"
  Ensure-Dir $dir
  $htmlPath = Join-Path $dir "index.html"

  $domains = if ($f.domains) { ($f.domains -join ', ') } else { '' }
  $respItems = ""
  if ($f.responsibilities) {
    foreach ($r in $f.responsibilities) { $respItems += "        <li>" + (HtmlEscape $r) + "</li>`n" }
  }
  $ifaceCards = ""
  if ($f.interfaces_links) {
    foreach ($link in $f.interfaces_links) {
      $iface = $INTERFACES."$link"
      if ($iface) {
        $ifaceCards += @"
      <div class="card">
        <h3 style="margin:0">$link</h3>
        <p><strong>Owner:</strong> $(HtmlEscape $iface.owner)</p>
        <p><em>$(HtmlEscape $iface.purpose)</em></p>
        <p><a href="/pages/interfaces/$link.html">Open</a></p>
      </div>
"@
        Ensure-InterfaceStub -id $link
      }
    }
  }

  $title = "$(HtmlEscape $f.name) • Fairy of Avalon"
  $envLoc = if ($f.environment.location) { HtmlEscape $f.environment.location } else { '' }

  $html = @"
<!doctype html><html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>$title</title>
<style>
body{margin:0;background:#0b0b0b;color:#eee;font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif}
header{padding:14px 16px;border-bottom:1px solid #222}
main{max-width:1100px;margin:0 auto;padding:16px}
.card{border:1px solid #222;border-radius:10px;padding:16px;background:#121212;margin:16px 0}
ul{margin:8px 0 0 18px}
a{color:#cde3ff}
</style>
</head><body>
<header><a href="/" style="color:#cde3ff;text-decoration:none">← Home</a></header>
<main>
  <div class="card">
    <h2 style="margin:0">$(HtmlEscape $f.name)</h2>
    <p><strong>Domains:</strong> $(HtmlEscape $domains)</p>
    <p><strong>Environment:</strong> $envLoc</p>
    <h3>Responsibilities</h3>
    <ul>
$respItems    </ul>
  </div>
  <div class="card">
    <h2 style="margin:0">Interfaces</h2>
$ifaceCards  </div>
</main>
</body></html>
"@

  Write-Text -path $htmlPath -content $html
  Write-Host "Scaffolded Fairy page: pages/fairies/$id/index.html"
  return $true
}

function Write-Models-Manifest {
  $wingless = @{}
  $withwings = @{}
  $pWingless = Join-Path $Root "asset\models\wingless"
  $pWith     = Join-Path $Root "asset\models\with-wings"
  if (Test-Path $pWingless) {
    Get-ChildItem -Path $pWingless -Filter *.vrm -File -ErrorAction SilentlyContinue | ForEach-Object {
      $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
      $wingless[$name] = ("asset/models/wingless/" + $_.Name)
    }
  }
  if (Test-Path $pWith) {
    Get-ChildItem -Path $pWith -Filter *.vrm -File -ErrorAction SilentlyContinue | ForEach-Object {
      $base = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
      $name = $base -replace '_wings$',''
      $withwings[$name] = ("asset/models/with-wings/" + $_.Name)
    }
  }
  $obj = [ordered]@{ wingless = $wingless; with_wings = $withwings }
  $json = $obj | ConvertTo-Json -Depth 6
  $outPath = Join-Path $Root "asset\models\models.json"
  Ensure-Dir (Split-Path $outPath)
  Set-Content -LiteralPath $outPath -Encoding UTF8 -NoNewline -Value $json
  Write-Host "Wrote asset/models/models.json"
}

function Process-Task($task) {
  switch ($task.type) {
    'scaffold_fairy'          { return (Scaffold-Fairy -id $task.fairy_id) }
    'write_models_manifest'   { Write-Models-Manifest; return $true }
    default {
      Write-Warning "Unknown task type: $($task.type)"
      return $false
    }
  }
}

# ---- Run --------------------------------------------------------------
$queue = Get-ChildItem -Path $QueueDir -Filter *.json -File -ErrorAction SilentlyContinue | Sort-Object Name
$processed = 0
foreach ($file in $queue) {
  try {
    $task = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
    $ok = Process-Task -task $task
    $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
    $dest = Join-Path $LogDir ("{0}_{1}" -f $stamp, $file.Name)
    Move-Item -LiteralPath $file.FullName -Destination $dest -Force
    if ($ok) { $processed++ }
  } catch {
    $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
    $dest = Join-Path $LogDir ("fail_{0}_{1}" -f $stamp, $file.Name)
    Move-Item -LiteralPath $file.FullName -Destination $dest -Force
    Write-Warning "Failed processing $($file.Name): $_"
  }
}

$summary = @{ ts=(Get-Date).ToString('s')+'Z'; processed=$processed; remaining=(Get-ChildItem -Path $QueueDir -Filter *.json -File -ErrorAction SilentlyContinue).Count } | ConvertTo-Json -Depth 4
Set-Content -LiteralPath (Join-Path $OutDir 'queue-runner.summary.json') -Encoding UTF8 -NoNewline -Value $summary
Write-Host "Queue Runner processed $processed task(s)."
exit 0
