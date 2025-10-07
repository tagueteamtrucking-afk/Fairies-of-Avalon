
param([switch]$ApplyFixes)
$Root = Split-Path -Parent $PSScriptRoot
$targets = Get-ChildItem -Recurse -File -Path $Root -Include *.html,*.htm,*.js,*.ts -ErrorAction SilentlyContinue
$hits = @()
$patterns = @('\?v=\w+','\?ver=\w+','version=20\d{2}\d*','location\.(assign|replace|href)\s*\([^)]*\?v=','service\s*worker','navigator\.serviceWorker')
foreach($f in $targets){
  $t = Get-Content -Raw -Path $f.FullName
  $found = @()
  foreach($p in $patterns){ if ($t -match $p) { $found += $p } }
  if ($found.Count -gt 0){ $hits += @{ file=$f.FullName; patterns=$found } }
}
# Simple fix: if index.html contains a forced redirect to ?v=..., neutralize it.
$changes = @()
$index = Join-Path $Root 'index.html'
if (Test-Path $index){
  $txt = Get-Content -Raw -Path $index
  $before = $txt
  $txt = $txt -replace '(location\.(assign|replace)\s*\(\s*[\'"][^\'"]+\?v=[^\'"]+[\'"]\s*\)\s*;)', '<!-- removed version redirect -->'
  $txt = $txt -replace '(if\s*\(\s*![^)]*searchParams\.has\(\s*[\'"]v[\'"]\s*\)\s*\)\s*\{\s*location\.replace\([^}]+\}\s*)', '<!-- removed param gate -->'
  if ($ApplyFixes -and $txt -ne $before) {
    Set-Content -Path $index -Value $txt -NoNewline -Encoding utf8
    $changes += @{ file=$index; change="removed v-param redirect" }
  }
}
# Report
$outDir = Join-Path $Root 'pages/diagnostics'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$now=(Get-Date).ToUniversalTime().ToString('s')+'Z'
$result = @{ updated=$now; hits=$hits; applied=$changes; apply=$ApplyFixes.IsPresent }
[IO.File]::WriteAllText((Join-Path $outDir 'version-scan.json'), ($result|ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
Write-Host "Sweeper complete. Hits: $($hits.Count)"
if ($ApplyFixes) { Write-Host "Fixes applied: $($changes.Count)" }
