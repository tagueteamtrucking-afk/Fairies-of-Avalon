
param(
  [Parameter()][object]$ApplyFixes = $false,
  [Parameter()][string]$IndexFile = "index.html"
)

function To-Bool([object]$x){
  if ($x -is [bool]) { return $x }
  if ($null -eq $x) { return $false }
  $s = [string]$x
  if ([string]::IsNullOrWhiteSpace($s)) { return $false }
  $s = $s.Trim().ToLower()
  if ($s -in @("1","true","t","yes","y","on")) { return $true }
  if ($s -in @("0","false","f","no","n","off")) { return $false }
  try { return [bool]$x } catch { return $false }
}
$apply = To-Bool $ApplyFixes

$Root = Split-Path -Parent $PSScriptRoot

# Collect candidate files
$targets = Get-ChildItem -Recurse -File -Path $Root -Include *.html,*.htm,*.js,*.ts -ErrorAction SilentlyContinue

$hits = @()

# Regex patterns as single-quoted here-strings
$patForcedRedirect = @'
location\.(assign|replace)\s*\(\s*["'][^"']+\?v=[^"']+["']\s*\)\s*;?
'@

$patVParamGate = @'
searchParams\.has\(\s*["']v["']\s*\)
'@

$patHardcodedParam = @'
\?v=[0-9A-Za-z\-._]+
'@

foreach($f in $targets){
  try {
    $text = Get-Content -Raw -Path $f.FullName -Encoding UTF8
  } catch {
    continue
  }
  $found = @()

  if ([regex]::IsMatch($text, $patForcedRedirect, 'IgnoreCase, Singleline')) { $found += "forced-v-redirect" }
  if ([regex]::IsMatch($text, $patVParamGate, 'IgnoreCase, Singleline')) { $found += "searchParams-v-check" }
  if ([regex]::IsMatch($text, $patHardcodedParam, 'IgnoreCase')) { $found += "hardcoded-?v" }

  if ($found.Count -gt 0) {
    $hits += @{ file = $f.FullName; matches = $found }
  }
}

# Optional neutralization for root index file only
$changes = @()
$indexPath = Join-Path $Root $IndexFile
if (Test-Path $indexPath) {
  $txt = Get-Content -Raw -Path $indexPath -Encoding UTF8
  $orig = $txt

  $reForced = [regex]::new($patForcedRedirect, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $reGate   = [regex]::new($patVParamGate,     [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)

  $txt = $reForced.Replace($txt, '<!-- removed forced ?v= redirect -->')
  $txt = $reGate.Replace($txt, '/* removed v-param gate */ false')

  if ($apply -and $txt -ne $orig) {
    Set-Content -Path $indexPath -Value $txt -NoNewline -Encoding UTF8
    $changes += @{ file = $indexPath; change = "neutralized forced ?v= redirects / gates" }
  }
}

# Write report
$outDir = Join-Path $Root 'pages/diagnostics'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$now = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
$report = @{ updated = $now; apply = $apply; index = $IndexFile; hits = $hits; applied = $changes }
[IO.File]::WriteAllText((Join-Path $outDir 'version-scan.json'), ($report | ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)

Write-Host ("Sweeper complete. Hits: {0}. Fixes applied: {1}" -f $hits.Count, $changes.Count)
