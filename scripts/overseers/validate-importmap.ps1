# Validates that any HTML file importing 'three' / 'three/addons/' / '@pixiv/three-vrm' includes an <script type="importmap">.
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
$targets = @(
  (Join-Path $repoRoot 'index.html'),
  (Join-Path $repoRoot 'pages')
)

# Collect HTML files
$files = @()
foreach($t in $targets){
  if (Test-Path $t -PathType Leaf) {
    $files += Get-Item -LiteralPath $t
  } elseif (Test-Path $t) {
    $files += Get-ChildItem -LiteralPath $t -Filter *.html -Recurse -File
  }
}

$violations = @()

# Regex patterns (single-quoted; doubled single-quotes inside)
$patternUsesModules = 'from\s+["''](@pixiv/three-vrm|three/addons/|three)["'']'
$patternImportMap   = '<script[^>]+type=["'']importmap["'']'

foreach($f in $files){
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $usesThree    = $html -match $patternUsesModules
  $hasImportMap = $html -match $patternImportMap
  if ($usesThree -and -not $hasImportMap){
    $violations += $f.FullName
  }
}

if ($violations.Count -gt 0){
  Write-Host "Import map required but missing in:"
  $violations | ForEach-Object { Write-Host " - $_" }
  Write-Host ""
  Write-Host "Add this to the <head> of those pages (adjust CDN if needed):"
  Write-Host @'
<script type="importmap">
{
  "imports": {
    "three": "https://unpkg.com/three@0.161.0/build/three.module.js",
    "three/addons/": "https://unpkg.com/three@0.161.0/examples/jsm/",
    "@pixiv/three-vrm": "https://unpkg.com/@pixiv/three-vrm@2.0.0/lib/three-vrm.module.js"
  }
}
</script>
'@
  throw "Import map missing in one or more module pages."
} else {
  Write-Host "Import map validation passed."
}
