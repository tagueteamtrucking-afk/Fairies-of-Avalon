param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)
$ErrorActionPreference='Stop'
$dir = Join-Path $RepoRoot 'asset/textures/wallpapers'
if(!(Test-Path $dir)){ Write-Host "No wallpapers dir: $dir"; exit 0 }
$patterns = @('*.jpg','*.jpeg','*.png','*.webp','*.gif')
$files = @()
foreach($pat in $patterns){
  $files += Get-ChildItem -LiteralPath $dir -File -Recurse -Include $pat -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Replace($RepoRoot,'').Replace('\','/')
    if($rel.StartsWith('/')){ $rel = $rel.Substring(1) }
    $rel
  }
}
$files = $files | Sort-Object -Unique
if($files.Count -eq 0){ Write-Host "No wallpapers found."; exit 0 }
$outPath = Join-Path $dir 'manifest.json'
$json = ($files | ConvertTo-Json -Depth 5)
Set-Content -LiteralPath $outPath -Value $json -Encoding UTF8
Write-Host "Wrote $outPath with $($files.Count) entries."
