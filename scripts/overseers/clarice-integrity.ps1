[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
$scopes = @(
  "Cody's Memory.yaml",
  "asset/models",
  "asset/wings",
  "asset/winged-models",
  "pages/apps",
  ".github/workflows",
  "scripts/overseers"
)
$files = @()
foreach($scope in $scopes){
  $p = Join-Path $RepoRoot $scope
  if (Test-Path $p){
    if ((Get-Item $p).PSIsContainer){
      $files += Get-ChildItem $p -Recurse -File
    } else {
      $files += Get-Item $p
    }
  }
}
$resultFiles = @()
foreach($f in $files){
  try{
    $h = Get-FileHash -Path $f.FullName -Algorithm SHA256
    $resultFiles += [pscustomobject]@{
      path = ($f.FullName.Substring((Resolve-Path $RepoRoot).Path.Length).TrimStart('\','/') -replace '\\','/')
      sha256 = $h.Hash.ToLower()
      bytes = $f.Length
    }
  }catch{}
}
# Simple suspicious heuristics
$suspicious = @()
foreach($f in $resultFiles){
  if ($f.path -match '\.(exe|dll|bat|cmd|sh|ps1)\.txt$') { $suspicious += $f }
  if ($f.path -match '\.(zip|rar)$' -and $f.bytes -gt 200MB) { $suspicious += $f }
  if ($f.path -match '\.(js|ps1)$' -and (Split-Path $f.path -Leaf) -match '\s') { $suspicious += $f }
}

$outDir = Join-Path $RepoRoot "pages/apps/clarice"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$report = [ordered]@{
  generated = Iso()
  scopes = $scopes
  files = $resultFiles
  suspicious = $suspicious | Sort-Object path -Unique
}
($report | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir "security-report.json") -Encoding utf8NoBOM
Write-Host "Security report written."
exit 0
