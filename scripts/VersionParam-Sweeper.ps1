
param(
  [bool]$ApplyFixes = $false,
  [string]$IndexFile = "index.html"
)

$Root = Split-Path -Parent $PSScriptRoot

# Collect candidate files
$targets = Get-ChildItem -Recurse -File -Path $Root -Include *.html,*.htm,*.js,*.ts -ErrorAction SilentlyContinue

$hits = @()

# Regex patterns defined as single-quoted here-strings (no escaping headaches)
$patForcedRedirect = @'
location\.(assign|replace)\s*\(\s*["'][^"']+\?v=[^"']+["']\s*\)\s*;?
'@

$patVParamGate = @'
searchParams\.has\(\s*["']v["']\s*\)
'@

$patHardcodedParam = @'
\?v=[0-9A-Za-z\-._]+
'@

# Detect hits across repo
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

# Optional neutralization for the root index.html only (non-destructive: comment or benign replace)
$changes = @()
$indexPath = Join-Path $Root $IndexFile
if (Test-Path $indexPath) {
  $txt = Get-Content -Raw -Path $indexPath -Encoding UTF8
  $orig = $txt

  $reForced = [regex]::new($patForcedRedirect, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $reGate   = [regex]::new($patVParamGate,     [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)

  # Replace forced redirects with an HTML comment
  $txt = $reForced.Replace($txt, '<!-- removed forced ?v= redirect -->')

  # Replace any conditional gate using searchParams.has('v') with a benign false
  $txt = $reGate.Replace($txt, '/* removed v-param gate */ false')

  if ($ApplyFixes -and $txt -ne $orig) {
    Set-Content -Path $indexPath -Value $txt -NoNewline -Encoding UTF8
    $changes += @{ file = $indexPath; change = "neutralized forced ?v= redirects / gates" }
  }
}

# Write report
$outDir = Join-Path $Root 'pages/diagnostics'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$now = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
$report = @{ updated = $now; apply = $ApplyFixes; index = $IndexFile; hits = $hits; applied = $changes }
[IO.File]::WriteAllText((Join-Path $outDir 'version-scan.json'), ($report | ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)

Write-Host ("Sweeper complete. Hits: {0}. Fixes applied: {1}" -f $hits.Count, $changes.Count)
