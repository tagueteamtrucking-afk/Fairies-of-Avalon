[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$SeedPath="",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){return "world"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { throw "No seeds directory found: $worldsDir" }

# Resolve seed
$seedFile = $null
if ($SeedPath) {
  $candidate = Join-Path $RepoRoot $SeedPath
  if (-not (Test-Path $candidate)) { throw "Seed file not found: $SeedPath" }
  $seedFile = Get-Item $candidate
} else {
  $files = Get-ChildItem $worldsDir -Filter *.json | Sort-Object LastWriteTime -Descending
  if ($files.Count -eq 0) { throw "No seed files found under /pages/apps/alexandria/worlds. Generate one first." }
  $seedFile = $files | Select-Object -First 1
}
try{ $seed = Get-Content -Raw -Path $seedFile.FullName | ConvertFrom-Json -Depth 100 }catch{ throw "Invalid seed JSON: $($seedFile.FullName)" }

# Load bible taxonomy
$tax = $null
$biblePath = Join-Path $RepoRoot "pages/apps/alexandria/knowledge/bible-taxonomy.json"
if (Test-Path $biblePath){ try{ $tax = Get-Content -Raw -Path $biblePath | ConvertFrom-Json -Depth 100 }catch{ $tax=$null } }
function Pick([object[]]$arr, [string]$fallback){ if($arr -and $arr.Count -gt 0){ return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] } return $fallback }
function Picks([object[]]$arr, [int]$n){ if(-not $arr){ return @() } $m=[Math]::Min($n,$arr.Count); return @($arr | Get-Random -Count $m) }

$bible = [pscustomobject]@{
  id = "bible-" + (Get-Date -Format 'yyyyMMddHHmmss')
  seed_id = $seed.id
  title = $seed.title
  generated = Iso
  format_version = "1.0.0"
  overview = @{
    pitch = $seed.starter_hook
    themes = @($seed.tags)
    pillars = $seed.pillars
    cosmology = $seed.cosmology
  }
  cultures = (Picks $tax.cultures 3)
  governments = (Picks $tax.governments 2)
  religions = (Picks $tax.religions 2)
  languages = (Picks $tax.languages 3)
  economy = @{
    currencies = (Picks $tax.currencies 2)
    materials = (Picks $tax.materials 3)
    resources = $null
  }
  magic = @{
    schools = (Picks $tax.magic_schools 2)
    costs = (Picks $tax.magic_costs 2)
    intensity = $seed.pillars.magic_system
  }
  color_palettes = (Picks $tax.color_palettes 2)
  travel = (Picks $seed.pillars.travel 1)
  bestiary = (Picks $tax.creatures 3)
  vehicles = (Picks $tax.vehicles 2)
  factions = $seed.factions
}

# Optional LLM enrichment (non-fatal)
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $prompt = @"
Write brief (40–60 word) paragraphs for each of these sections: overview, cultures, religions, magic (costs & schools), economy, and travel.
Seed:
$($seed | ConvertTo-Json -Depth 40)
Current bible skeleton:
$($bible | ConvertTo-Json -Depth 20)
Return ONLY JSON with keys: { ""overview"": ""..."", ""cultures"": [""..."",""...""], ""religions"": [""..."",""...""], ""magic"": ""..."", ""economy"": ""..."", ""travel"": ""..."" }
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.bible.enriched.json"
  try {
    & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false
    $j = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 100
    if ($j) {
      $bible | Add-Member -NotePropertyName "prose" -NotePropertyValue $j -Force
    }
  } catch {}
}

$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/bible"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.bible.json"
$rel  = "/apps/alexandria/worlds/bible/$name"

($bible | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir $name) -Encoding utf8NoBOM

# Index
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$bible.id; ts=(Iso) }
($index | ConvertTo-Json -Depth 100) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "Lore Bible written: $rel"
exit 0
