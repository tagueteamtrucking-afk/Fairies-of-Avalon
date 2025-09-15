[CmdletBinding()]
param([string]$RepoRoot=".", [switch]$ForceFallback)

$ErrorActionPreference='Stop'

try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}

function IsoNow(){ (Get-Date).ToUniversalTime().ToString("o") }
function Encode-UrlPath([string]$p){
  if (-not $p) { return $p }
  ($p -replace ' ', '%20' -replace '\(', '%28' -replace '\)', '%29')
}

# ---------- Memory ----------
$memPath = Join-Path $RepoRoot "Cody's Memory.yaml"
$mem = @{}
try { $mem = (Get-Content -Raw -Path $memPath) | ConvertFrom-Yaml } catch { $mem=@{} }

$siteName = $mem.project.world  ; if (-not $siteName) { $siteName = "Avalon" }
$domain   = $mem.project.domain ; if (-not $domain)  { $domain  = "fairiesofavalon.com" }

# ---------- Context ----------
$assistants = @()
$assistantsJson = Join-Path $RepoRoot "pages/apps/overseers/assistants.json"
if (Test-Path $assistantsJson) { try { $assistants = Get-Content -Raw -Path $assistantsJson | ConvertFrom-Json -Depth 40 } catch {} }

$wall1 = $null
$wallsJson = Join-Path $RepoRoot "pages/apps/overseers/wallpapers.json"
if (Test-Path $wallsJson) {
  try {
    $walls = Get-Content -Raw -Path $wallsJson | ConvertFrom-Json -Depth 40
    if ($walls -and $walls.Count -gt 0) { $wall1 = '/' + ($walls[0].path.TrimStart('/')) }
  } catch {}
}
if (-not $wall1) {
  $wallDir = Join-Path $RepoRoot "asset/textures/wallpapers"
  if (Test-Path $wallDir) {
    $f = Get-ChildItem $wallDir -File | Where-Object { $_.Extension -match 'png|jpe?g|webp' } | Sort-Object Name | Select-Object -First 1
    if ($f) {
      $root=(Resolve-Path -LiteralPath $RepoRoot).Path
      $full=(Resolve-Path -LiteralPath $f.FullName).Path
      $wall1 = '/' + ($full.Substring($root.Length).TrimStart('\','/') -replace '\\','/')
    }
  }
}

# ---------- Outputs ----------
$outDir = Join-Path $RepoRoot "pages/themes"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$htmlOut = Join-Path $outDir "landing.generated.html"
$cssOut  = Join-Path $outDir "landing.generated.css"
$ver = "7"  # cache-bust

function Write-CSS(){
$css = @"
.hero{ position:relative; min-height:54vh; background-size:cover; background-position:center; }
.hero .overlay{
  position:absolute; inset:0; background:linear-gradient(180deg,rgba(0,0,0,.25),rgba(0,0,0,.55));
  color:#fff; display:flex; flex-direction:column; justify-content:center; align-items:center; text-align:center; padding:4rem 1rem;
}
.wrap{max-width:1100px;margin:24px auto;padding:0 12px}
.cta{display:inline-block;margin:.25rem .35rem;padding:.45rem .8rem;border:1px solid #fff;border-radius:.6rem;color:#fff;text-decoration:none}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px;margin-top:10px}
.tile{display:flex;flex-direction:column;gap:2px;padding:10px;border:1px solid #eee;border-radius:.5rem;text-decoration:none;color:inherit;background:rgba(255,255,255,.65)}
.tile small{color:#666}
"@
  Set-Content -Path $cssOut -Value $css -Encoding utf8NoBOM
}

# JS runtime “self-heal” (single-quoted here-string; literal)
$runtimeHeal = @'
<script type="module">
(async ()=>{
  const hero = document.querySelector(".hero");
  if (!hero) return;
  const bg = getComputedStyle(hero).backgroundImage || "";
  const blank = !bg || bg === "none" || /url\(""\)/.test(bg);
  async function tryApply(){
    try{
      const res = await fetch("/apps/overseers/wallpapers.json?ts=" + Date.now(), { cache: "no-store" });
      const list = await res.json();
      if (Array.isArray(list) && list.length){
        const p = "/" + String(list[0].path || "").replace(/^\/+/, "");
        const u = p.replace(/ /g,"%20").replace(/\(/g,"%28").replace(/\)/g,"%29");
        hero.style.backgroundImage = "url('" + u + "')";
      }
    }catch{}
  }
  if (blank) { await tryApply(); }
})();
</script>
'@

function Write-Deterministic(){
  $tiles = ""
  foreach ($a in $assistants) {
    $href = $a.path; $name = $a.name
    $state = $a.microapp_exists ? "Open" : "Soon"
    $tiles += "<a class=""tile"" href=""$href""><span>$name</span><small>$state</small></a>`n"
  }
  $bgEnc = Encode-UrlPath $wall1
  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$siteName — Welcome</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <link rel="stylesheet" href="./landing.generated.css?v=$ver">
  <style>body{margin:0;}</style>
</head>
<body>
  <header class="hero" style="background-image:url('$bgEnc')">
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
  $runtimeHeal
</body>
</html>
"@
  Set-Content -Path $htmlOut -Value $html -Encoding utf8NoBOM
  Write-CSS
  Write-Host "Landing (deterministic) generated at $htmlOut"
}

function Wrap-LLM([string]$inner){
  $html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$siteName — Welcome</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="stylesheet" href="/app.css">
  <link rel="stylesheet" href="./landing.generated.css?v=$ver">
  <style>body{margin:0;}</style>
</head>
<body>
  <main>
  $inner
  </main>
  $runtimeHeal
</body>
</html>
"@
  Set-Content -Path $htmlOut -Value $html -Encoding utf8NoBOM
  Write-CSS
  Write-Host "Landing (LLM) generated at $htmlOut"
}

if ($ForceFallback) { Write-Deterministic; exit 0 }

# Try LLM (non-fatal)
$haveOpenAI = [bool]$env:OPENAI_API_KEY
$inner = $null
if ($haveOpenAI) {
  $assistantNames = ($assistants | ForEach-Object { $_.name }) -join ', '
  $ctx = @"
Return ONLY the <main>...</main> inner HTML for "$siteName" ($domain).
Include a hero if '$wall1' exists; include tiles for: $assistantNames with /apps/{id}/ links; include buttons to Overseers Hub and Console.
Plain, semantic HTML. No <html>/<head>/<body>.
"@
  $tmp = Join-Path $env:RUNNER_TEMP "landing.llm.html"
  $bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
  try {
    & $bridge -Prompt $ctx -OutFile $tmp -DryRun:$false
    $inner = Get-Content -Raw -Path $tmp
  } catch { $inner = $null }
}

if (-not $inner -or $inner -match 'LLM Bridge Fallback' -or $inner -match 'Generated Content \(Fallback\)') {
  Write-Deterministic
} else {
  Wrap-LLM $inner
}
exit 0
