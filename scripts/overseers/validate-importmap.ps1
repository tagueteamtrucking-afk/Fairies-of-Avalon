# Fails if any HTML that uses 'three' / '@pixiv/three-vrm' modules lacks an importmap tag.
$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$paths = @(
  Join-Path $repoRoot 'index.html',
  Join-Path $repoRoot 'pages'
)

$files = @()
foreach($p in $paths){
  if (Test-Path $p){
    $files += if (Test-Path $p -PathType Leaf) { Get-Item $p } else { Get-ChildItem -Path $p -Filter *.html -Recurse -File }
  }
}

$violations = @()
foreach($f in $files){
  $html = Get-Content -LiteralPath $f.FullName -Raw
  $usesThree = $html -match "from\s+['""](@pixiv/three-vrm|three/addons/|three)['""]"
  $hasImportMap = $html -match '<script[^>]+type=["'"]importmap["'"]'
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
