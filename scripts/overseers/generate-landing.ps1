[CmdletBinding()]
param([string]$RepoRoot=".")

$ErrorActionPreference='Stop'

try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }

$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem = @{}
try { $mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml } catch { $mem=@{} }

$siteName = $mem.project.world; if (-not $siteName) { $siteName = "Avalon" }
$domain   = $mem.project.domain; if (-not $domain)  { $domain  = "fairiesofavalon.com" }

# Gather context
$assistants = @()
$assistantsJson = Join-Path $RepoRoot "pages/apps/overseers/assistants.json"
if (Test-Path $assistantsJson) {
  try { $assistants = Get-Content -Raw -Path $assistantsJson | ConvertFrom-Json -Depth 40 } catch {}
}
$walls = @()
$wallsJson = Join-Path $RepoRoot "pages/apps/overseers/wallpapers.json"
$wall1 = $null
if (Test-Path $wallsJson) {
  try {
    $walls = Get-Content -Raw -Path $wallsJson | ConvertFrom-Json -Depth 40
    if ($walls -and $walls.Count -gt 0) { $wall1 = '/' + ($walls[0].path.TrimStart('/')) }
  } catch {}
}
if (-not $wall1) {
  # Fallback: scan assets
  $wallDir = Join-Path $RepoRoot "asset/textures/wallpapers"
  if (Test-Path $wallDir) {
    $f = Get-ChildItem $wallDir -File | Where-Object { $_.Extension -match 'png|jpe?g|webp' } | Sort-Object Name | Select-Object -First 1
    if ($f) { $root=(Resolve-Path -LiteralPath $RepoRoot).Path; $full=(Resolve-Path -LiteralPath $f.FullName).Path; $wall1 = '/' + ($full.Substring($root.Length).TrimStart('\','/') -replace '\\','/') }
  }
}

$outDir = Join-Path $RepoRoot "pages/themes"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$htmlOut = Join-Path $outDir "landing.generated.html"
$cssOut  = Join-Path $outDir "landing.generated.css"

$haveOpenAI = [bool]$env:OPENAI_API_KEY

if ($haveOpenAI) {
  # Compose a compact prompt for the LLM bridge
  $assistantNames = ($assistants | ForEach-Object { $_.name }) -join ', '
  $ctx = @"
You are generating a minimal, production-safe landing page for the site "$siteName" ($domain).
Constraints:
- No framework, plain HTML + a tiny CSS file.
- Use "/manifest.webmanifest", "/app.css", and if available, "/importmap.json" is fine but not required.
- If wallpaper exists at "$wall1", use it as a hero background with an overlay.
- Include a row of assistant tiles for: $assistantNames (use "/apps/{id}/" links from assistants.json when present).
- Include call-to-action buttons: "Overseers Hub" (/apps/overseers/hub/) and "Open Console" (/apps/overseers/console.html).
- Keep total HTML under ~300 lines.

Return ONLY the <main>...</main> inner HTML content (no <html>, no <head>), using semantic sections.
"@

  $tmpFile = Join-Path $env:RUNNER_TEMP "landing.llm.html"
  $bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"

  try {
    & $bridge -Prompt $ctx -OutFile $tmpFile -DryRun:$false
    $inner = Get-Content -Raw -Path $tmpFile
    $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$siteName — Welcome</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <link rel="stylesheet" href="./landing.generated.css">
  <style>body{margin:0;}</style>
</head>
<body>
  <main>
  $inner
  </main>
</body>
</html>
"@
    Set-Content -Path $htmlOut -Value $html -Encoding utf8NoBOM
  }
  catch {
    Write-Host "::warning:: LLM Bridge failed; writing fallback landing."
    $haveOpenAI=$false
  }
}

if (-not $haveOpenAI) {
  # Deterministic fallback landing using assets we already have
  $bg = $wall1
  $tiles = ""
  foreach ($a in $assistants) {
    $href = $a.path
    $name = $a.name
    $state = $a.microapp_exists ? "Open" : "Soon"
    $tiles += "<a class=""tile"" href=""$href""><span>$name</span><small>$state</small></a>`n"
  }
  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$siteName — Welcome</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <link rel="stylesheet" href="./landing.generated.css">
  <style>body{margin:0;}</style>
</head>
<body>
  <header class="hero">
    <div class="overlay">
      <h1>$siteName</h1>
      <p>Welcome to $siteName. Explore the Overseers and their Fairies.</p>
      <p>
        <a class="cta" href="/apps/overseers/hub/">Overseers Hub</a>
        <a class="cta" href="/apps/overseers/console.html">Open Console</a>
      </p>
    </div>
  </header>
  <main class="wrap">
    <section>
      <h2>Fairies</h2>
      <div class="tiles">
        $tiles
      </div>
    </section>
  </main>
</body>
</html>
"@
  Set-Content -Path $htmlOut -Value $html -Encoding utf8NoBOM

  $css = @"
.hero{
  position:relative;min-height:54vh;
  background-image:url('$bg');background-size:cover;background-position:center;
}
.hero .overlay{
  position:absolute;inset:0;background:linear-gradient(180deg,rgba(0,0,0,.25),rgba(0,0,0,.55));
  color:#fff;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center;padding:4rem 1rem;
}
.wrap{max-width:1100px;margin:24px auto;padding:0 12px}
.cta{display:inline-block;margin:.25rem .35rem;padding:.45rem .8rem;border:1px solid #fff;border-radius:.6rem;color:#fff;text-decoration:none}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px;margin-top:10px}
.tile{display:flex;flex-direction:column;gap:2px;padding:10px;border:1px solid #eee;border-radius:.5rem;text-decoration:none;color:inherit;background:rgba(255,255,255,.65)}
.tile small{color:#666}
"@
  Set-Content -Path $cssOut -Value $css -Encoding utf8NoBOM
}

Write-Host "Landing generated at $(Resolve-Path $htmlOut)."
