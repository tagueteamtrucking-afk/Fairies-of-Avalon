[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$SeedPath="",       # optional; defaults to newest in /pages/apps/alexandria/worlds
  [switch]$ForceFallback      # when set, skip any LLM expansion even if key is present
)
$ErrorActionPreference='Stop'

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){return "world"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$root = (Resolve-Path $RepoRoot).Path
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { New-Item -ItemType Directory -Force -Path $worldsDir | Out-Null }

# Pick seed
$seedFile = $null
if ($SeedPath) {
  $candidate = (Join-Path $RepoRoot $SeedPath)
  if (-not (Test-Path $candidate)) {
    throw "Seed file not found: $SeedPath"
  }
  $seedFile = Get-Item $candidate
} else {
  $list = @()
  if (Test-Path $worldsDir){
    $list = Get-ChildItem $worldsDir -Filter *.json | Sort-Object LastWriteTime -Descending
  }
  if ($list.Count -eq 0) {
    throw "No seed files found under /pages/apps/alexandria/worlds. Generate one first."
  }
  $seedFile = $list | Select-Object -First 1
}

# Load seed JSON
try {
  $seed = Get-Content -Raw -Path $seedFile.FullName | ConvertFrom-Json -Depth 100
} catch {
  throw "Seed JSON is invalid: $($seedFile.FullName)"
}

# Derive outline (same as frontend)
function Build-Outline([object]$s){
  $tone = if($s.tags -and $s.tags.Count -ge 2){ $s.tags[1] } else { 'balanced' }
  $magic = $s.pillars.magic_system
  $travel = $s.pillars.travel
  $topo = $s.cosmology.planar_topology
  $conf = $s.conflict
  $f1 = if($s.factions.Count -ge 1){ $s.factions[0].name } else { 'Faction A' }
  $f2 = if($s.factions.Count -ge 2){ $s.factions[1].name } else { 'Faction B' }
@"
Act I — Setup:
• Introduce $($s.protagonist_archetype); show $magic and $travel.
• Inciting incident tied to $($s.starter_hook).

Act II — Trials:
• Faction clash: $f1 vs $f2.
• Conflict escalates ($conf); secrets of $topo surface.

Act III — Resolution:
• Choice tests values (tone: $tone). Gate via $($s.cosmology.portals).
"@
}

$outline = Build-Outline -s $seed

# Optional: try LLM expansion (non-fatal)
$expansion = $null
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $prompt = @"
You are Alexandria, a worldbuilding architect. Given this seed JSON, write concise expansions:
Return ONLY valid JSON with keys:
{
  "magic": "120-180 words expanding on the magic system (costs, risks, tells).",
  "cosmology": "120-180 words describing planar topology, thresholds, and travel.",
  "factions": "120-180 words summarizing the two named factions and their tension."
}
Seed:
$($seed | ConvertTo-Json -Depth 30)
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.expansion.json"
  try {
    & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false
    $expansion = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 50
  } catch { $expansion = $null }
}

# Build Markdown
$tags = if($seed.tags){ ($seed.tags -join ', ') } else { '' }
$now = Iso
$magic = $seed.pillars.magic_system
$travel= $seed.pillars.travel
$topo  = $seed.cosmology.planar_topology

$md = @"
# $($seed.title) — Lore Bible (v1)

**ID:** $($seed.id)
**Tags:** $tags
**Isekai:** $(if($seed.isekai){'Yes'}else{'No'})
**D&D Compatible:** $(if($seed.dnd_compatible){'Yes'}else{'No'})
**Generated:** $now

---

## 1. Overview

**Elevator pitch:** $($seed.starter_hook)

**Genre & Tone:** $tags

**Protagonist archetype:** $($seed.protagonist_archetype)

**Safety:** Content maturity — $($seed.safety.content_maturity)

## 2. Canon — Pillars

- **Magic system:** $magic
- **Tech level:** $($seed.pillars.tech_level)
- **Travel:** $travel

$(if($expansion -and $expansion.magic){"### 2.1 Magic Notes (expanded)
$($expansion.magic)
"}else{""})

## 3. Cosmology

- **Planar topology:** $topo
- **Portals / thresholds:** $($seed.cosmology.portals)

$(if($expansion -and $expansion.cosmology){"### 3.1 Cosmology Notes (expanded)
$($expansion.cosmology)
"}else{""})

## 4. Factions

$(if($seed.factions){
($seed.factions | ForEach-Object { "- **$($_.name)** — motif: $($_.motif); goal: $($_.goal)" }) -join "`n"
}else{"- (define at least two factions)"})

$(if($expansion -and $expansion.factions){"### 4.1 Faction Notes (expanded)
$($expansion.factions)
"}else{""})

**Relationships:**  
- TBD: alliances, rivalries, proxy conflicts.

## 5. Regions (seeds)

- Region A — hub tied to travel method ($travel).
- Region B — frontier where $($seed.conflict) is visible.
- Region C — secret or sacred site linked to $magic.

## 6. Culture & Language

- Language notes: $(if($seed.language_notes){ $seed.language_notes -join '; ' } else { '—' })
- Naming style: consonant clusters + vowel rules (define per culture).
- Taboos & rituals: define per faction/region.

## 7. Story Outline (derived)

```
$outline
```

## 8. Character Seeds

- **Allies:** guide, fixer, scholar.  
- **Antagonists:** zealot of $(if($seed.factions.Count -ge 2){$seed.factions[1].name}else{'the rival order'}), agent of $(if($seed.factions.Count -ge 1){$seed.factions[0].name}else{'the protectorate'}).  
- **Neutrals:** merchant, ferryman, archivist.

## 9. Lexicon (starter)

- **Core term 1** — definition.  
- **Core term 2** — definition.  
- **Artifact / spell** — cost, risk, tells.

## 10. Production Notes

- **Art palette:** silhouettes, motifs, color accents.  
- **Music:** ambient motifs for $magic scenes.  
- **Props/FX:** travel markers, faction insignias.

---

## Appendix A — Seed JSON
```json
$($seed | ConvertTo-Json -Depth 40)
```

*End of v1.*
"@

# Write file
$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/bibles"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.lore.md"
$path = Join-Path $outDir $name
Set-Content -Path $path -Value $md -Encoding utf8NoBOM

# Update index
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
# Dedup by path
$rel = "/apps/alexandria/worlds/bibles/$name"
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$seed.id; ts=(Iso) }
($index | ConvertTo-Json -Depth 20) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "Lore Bible written: $rel"
exit 0
