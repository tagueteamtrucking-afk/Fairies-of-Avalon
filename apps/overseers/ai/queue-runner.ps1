# Overseers Queue Runner
# Processes apps/overseers/queue/*.json and generates:
#  - pages/fairies/<id>/index.html
#  - pages/interfaces/<interface>.html
#  - asset/models/models.json
#  - asset/wings/manifest.json
# Auto-installs YAML support in GitHub Actions.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-ProjectRoot { return (Resolve-Path "$PSScriptRoot\..\..\..").Path }

function Ensure-YamlModule {
  if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) { return }
  try {
    Write-Host "Installing YAML support..."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
    }
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop | Out-Null
    Import-Module powershell-yaml -Force -ErrorAction Stop
  } catch {
    throw "Failed to install/import 'powershell-yaml': $($_ | Out-String)"
  }
}

function HtmlEscape([string]$s) {
  if ($null -eq $s) { return "" }
  $s = $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
  return $s
}
function Ensure-Dir([string]$p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
function Write-Text([string]$p,[string]$c){ Ensure-Dir (Split-Path $p); Set-Content -LiteralPath $p -Encoding UTF8 -NoNewline -Value $c }
function ToWebPath([string]$full,[string]$root) {
  $rel = $full.Substring($root.Length).TrimStart('\','/')
  return ($rel -replace '\\','/')
}

$Root     = Get-ProjectRoot
$QueueDir = Join-Path $Root 'apps\overseers\queue'
$LogDir   = Join-Path $Root 'apps\overseers\log'
$OutDir   = Join-Path $Root 'apps\overseers\out'
New-Item -ItemType Directory -Force -Path $QueueDir,$LogDir,$OutDir | Out-Null

# --- Memory ------------------------------------------------------------------
Ensure-YamlModule
$MemoryPath = Join-Path $Root "Cody's Memory.yaml"
if (-not (Test-Path $MemoryPath)) { throw "Memory file not found: $MemoryPath" }
$MEM = ConvertFrom-Yaml -Yaml (Get-Content -Raw -LiteralPath $MemoryPath -Encoding UTF8)

$FAIRIES    = @{}
foreach ($f in $MEM.entities.fairies) { $FAIRIES[$f.id] = $f }
$INTERFACES = $MEM.interfaces_registry

# --- Interface stub ----------------------------------------------------------
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

# --- Fairy scaffold ----------------------------------------------------------
function Scaffold-Fairy([string]$id) {
  if (-not $FAIRIES.ContainsKey($id)) { Write-Warning "Fairy '$id' not in Memory."; return $false }
  $f = $FAIRIES[$id]
  $dir = Join-Path $Root "pages\fairies\$id"
  Ensure-Dir $dir
  $htmlPath = Join-Path $dir "index.html"

  $domains = if ($f.domains) { ($f.domains -join ', ') } else { '' }
  $respItems = ""
  if ($f.responsibilities) { foreach ($r in $f.responsibilities) { $respItems += "        <li>" + (HtmlEscape $r) + "</li>`n" } }
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
  Write-Host "Scaffolded: pages/fairies/$id/index.html"
  return $true
}

# --- Models manifest ---------------------------------------------------------
function Write-Models-Manifest {
  $wingless = @{}
  $withwings = @{}

  $mRoot = Join-Path $Root "asset\models"
  if (Test-Path $mRoot) {
    $vrms = Get-ChildItem -Path $mRoot -Recurse -File -Include *.vrm -ErrorAction SilentlyContinue
    foreach ($v in $vrms) {
      $bn = [IO.Path]::GetFileNameWithoutExtension($v.Name)
      $rel = ToWebPath $v.FullName $Root
      $isWithDir = $v.FullName -imatch '[\\\/]with-wings[\\\/]'
      $isWithName = $bn -imatch '(^|[-_])(wing|wings)$'

      if ($isWithDir -or $isWithName) {
        $name = ($bn -replace '(^|[-_])(wing|wings)$','').Trim('_','-')
        if (-not $name) { $name = $bn }
        $withwings[$name] = $rel
      } else {
        $wingless[$bn] = $rel
      }
    }
  }

  $obj = [ordered]@{ wingless = $wingless; with_wings = $withwings }
  $json = $obj | ConvertTo-Json -Depth 6
  $outPath = Join-Path $Root "asset\models\models.json"
  Ensure-Dir (Split-Path $outPath)
  Set-Content -LiteralPath $outPath -Encoding UTF8 -NoNewline -Value $json
  Write-Host "Wrote: asset/models/models.json"
}

# --- Wings manifest ----------------------------------------------------------
function Get-WingKey([string]$basename) {
  # Normalize "Wing02", "wing2" => "wing02" when there are trailing digits.
  $b = $basename
  if ($b -match '(\d+)$') {
    $n = [int]$Matches[1]
    return ('wing{0:D2}' -f $n)
  } else {
    return $b.ToLower()
  }
}
function RoleFromSuffix([string]$suffixLower) {
  switch -regex ($suffixLower) {
    '^$'                           { return 'base' }
    '(^|[_\.-])(c|col|color)$'     { return 'color' }
    '(^|[_\.-])(e|em|emis.*)$'     { return 'emissive' }
    '(^|[_\.-])(n|nrm|normal)$'    { return 'normal' }
    'rough|rgh'                    { return 'roughness' }
    'metal|mtl|mr'                 { return 'metallic' }
    'ao|occlusion'                 { return 'occlusion' }
    default                        { return 'other' }
  }
}
function Write-Wings-Manifest {
  $sets = @{}
  $meshDir = Join-Path $Root "asset\wings"
  $texDir  = Join-Path $meshDir "textures"
  if (-not (Test-Path $meshDir)) { return }

  $meshes = Get-ChildItem -Path $meshDir -File -Include *.fbx,*.glb,*.gltf -ErrorAction SilentlyContinue
  foreach ($m in $meshes) {
    if ($m.DirectoryName -imatch '[\\\/]textures$') { continue }
    $base = [IO.Path]::GetFileNameWithoutExtension($m.Name)
    $key  = Get-WingKey $base
    $wObj = @{
      mesh     = ToWebPath $m.FullName $Root
      textures = @{}
    }
    # Find textures by shared number/prefix (case-insensitive)
    if (Test-Path $texDir) {
      $prefix = $base
      $tex = Get-ChildItem -Path $texDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -imatch ("^" + [regex]::Escape($prefix) + "($|[_\.-])") }
      foreach ($t in $tex) {
        $suffix = ($t.BaseName.Substring([Math]::Min($prefix.Length, $t.BaseName.Length))).ToLower()
        $role = RoleFromSuffix $suffix
        $wObj.textures[$role] = ToWebPath $t.FullName $Root
      }
    }
    $sets[$key] = $wObj
  }

  $obj = [ordered]@{ sets = $sets }
  $json = $obj | ConvertTo-Json -Depth 8
  $outPath = Join-Path $Root "asset\wings\manifest.json"
  Ensure-Dir (Split-Path $outPath)
  Set-Content -LiteralPath $outPath -Encoding UTF8 -NoNewline -Value $json
  Write-Host "Wrote: asset/wings/manifest.json"
}

# --- Task processor ----------------------------------------------------------
function Process-Task($task) {
  switch ($task.type) {
    'scaffold_fairy'         { return (Scaffold-Fairy -id $task.fairy_id) }
    'write_models_manifest'  { Write-Models-Manifest; return $true }
    'write_wings_manifest'   { Write-Wings-Manifest;  return $true }
    default { Write-Warning "Unknown task type: $($task.type)"; return $false }
  }
}

# --- Run ---------------------------------------------------------------------
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
