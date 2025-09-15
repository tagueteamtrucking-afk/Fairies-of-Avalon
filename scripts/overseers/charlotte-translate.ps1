[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Text="",
  [string]$Lang="es",
  [string]$Title="Untitled",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'

$outDir = Join-Path $RepoRoot "pages/apps/charlotte/translations"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$content = $null
if (-not $ForceFallback -and $env:OPENAI_API_KEY) {
  $prompt = @"
Translate to [$Lang]. Preserve meaning and tone. Return ONLY the translated text with markdown formatting preserved.
Source:
$Text
"@
  $bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
  $tmp = Join-Path $env:RUNNER_TEMP "charlotte.translated.md"
  try {
    & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false
    $content = Get-Content -Raw -Path $tmp
  } catch { $content = $null }
}
if (-not $content) {
  $content = "# [Placeholder] Translation to $Lang\n\n" + $Text
}

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if(-not $s){return "text"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$name = "tr-" + (Get-Date -Format 'yyyyMMddHHmmss') + "-" + (Slug $Lang) + "-" + (Slug $Title) + ".md"
$rel = "/apps/charlotte/translations/$name"
Set-Content -Path (Join-Path $outDir $name) -Value $content -Encoding utf8NoBOM

# Update index.json
$idxPath = Join-Path $outDir "index.json"
$idx = @()
if (Test-Path $idxPath){ try { $idx = Get-Content -Raw -Path $idxPath | ConvertFrom-Json } catch { $idx=@() } }
$idx += [pscustomobject]@{ path = $rel; lang=$Lang; title=$Title; ts = (Iso()) }
($idx | ConvertTo-Json -Depth 10) | Set-Content -Path $idxPath -Encoding utf8NoBOM

Write-Host "Translation written: $rel"
exit 0
