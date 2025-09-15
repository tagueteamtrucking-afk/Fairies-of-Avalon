[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$Prompt="",
  [switch]$Isekai,
  [switch]$DndCompat,
  [int]$Count=1,
  [switch]$ForceFallback
)

$ErrorActionPreference='Stop'

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") }
function Slug([string]$s){ if(-not $s){return "seed"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

function New-LocalSeed([string]$prompt,[bool]$isekai,[bool]$dnd){
  $pick = { param($arr) $arr | Get-Random }
  $genres   = @('fantasy','science-fantasy','solarpunk','dieselpunk','cyber-fantasy','mythic','weird')
  $tones    = @('hopeful','grimbright','noblebright','nobledark','cozy','epic','mysterious')
  $magic    = @('ritual','runes','spirit contracts','songcraft','weave','divine','artifice','alchemy','bloodline','psionics','forbidden')
  $tech     = @('stone','medieval','clockwork','renaissance','industrial','diesel','atomic','digital','biotech','post-scarcity')
  $travel   = @('portals','skyships','leylines','dreamways','undersea gates','astral currents','wyrm tunnels','rail','caravans','orbital lifts')
  $conf     = @('invasion','succession','apocalypse averted','heist','holy war','colonization','rebellion','first contact','cataclysm aftermath')
  $arch     = @('reluctant hero','archivist','witch-engineer','paladin out of time','ranger-navigator','bard-spy','alchemist-medic','cartographer')
  $align    = @('LG','NG','CG','LN','N','CN','LE','NE','CE')

  $seed = [ordered]@{
    id = "seed-" + (Get-Random -Maximum 2147483647)
    title = "$(if($isekai){'Isekai: '})$([string]::IsNullOrWhiteSpace($prompt) ? (& $pick $genres) + ' saga' : $prompt.Substring(0,[Math]::Min(60,$prompt.Length)))"
    tags = @((& $pick $genres), (& $pick $tones))
    isekai = $isekai
    dnd_compatible = $dnd
    pillars = @{
      magic_system = (& $pick $magic)
      tech_level   = (& $pick $tech)
      travel       = (& $pick $travel)
    }
    conflict = (& $pick $conf)
    protagonist_archetype = (& $pick $arch)
    starter_hook = "A catalyst forces action: $prompt"
    factions = @(
      @{ name='The Aegis';    motif='protective order';   goal='preserve balance' },
      @{ name='The Crucible'; motif='radical progress';   goal='reshape the world' }
    )
    cosmology = @{
      planar_topology = (& $pick @('world-tree','archipelago','ringworld','stacked planes','floating continents','nested bubbles'))
      portals = (& $pick @('rare & costly','seasonal','unstable','omnipresent'))
    }
    language_notes = @('Bind runes to phonemes for magic resonance.')
    safety = @{ content_maturity = 'pg-13' }
    references = @{ prompt = $prompt }
    suggested_alignment_bias = $(if($dnd){ & $pick $align } else { 'n/a' })
    format_version = '1.0.0'
  }
  $outline = @"
Act I — Setup:
• Introduce $($seed.protagonist_archetype); show $($seed.pillars.magic_system) and $($seed.pillars.travel).
• Inciting incident tied to $($seed.starter_hook).

Act II — Trials:
• Faction clash: $($seed.factions[0].name) vs $($seed.factions[1].name).
• Conflict escalates ($($seed.conflict)); secrets of $($seed.cosmology.planar_topology) surface.

Act III — Resolution:
• Choice tests values (tone: $($seed.tags[1])). Gate via $($seed.cosmology.portals).
"@
  return @{ seed = $seed; outline = $outline }
}

function Write-SeedFiles([hashtable]$obj,[string]$dir){
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $title = $obj.seed.title
  $name  = "seed-" + (Iso()) + "-" + (Slug $title) + ".json"
  $path  = Join-Path $dir $name
  ($obj.seed | ConvertTo-Json -Depth 40) | Set-Content -Path $path -Encoding utf8NoBOM
  return $path
}

$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
$newPaths = @()

# Try LLM unless forced off
if (-not $ForceFallback -and $env:OPENAI_API_KEY) {
  $instruction = @"
You are Alexandria, a worldbuilding architect. Produce $Count structured world "seed" JSON objects (array), each matching this schema:

{
  "id": "string",
  "title": "string",
  "tags": ["genre","tone"],
  "isekai": true|false,
  "dnd_compatible": true|false,
  "pillars": { "magic_system": "string", "tech_level": "string", "travel": "string" },
  "conflict": "string",
  "protagonist_archetype": "string",
  "starter_hook": "string",
  "factions": [ { "name": "string", "motif": "string", "goal": "string" } ],
  "cosmology": { "planar_topology": "string", "portals": "string" },
  "language_notes": ["string"],
  "safety": { "content_maturity": "string" },
  "references": { "prompt": "string" },
  "suggested_alignment_bias": "string",
  "format_version": "1.0.0"
}

Constraints:
- Keep dnd_compatible=${DndCompat}; keep isekai=${Isekai}.
- Titles and fields must be safe for public display.
- Return ONLY valid JSON (an array of seed objects), no prose.
User prompt: "${Prompt}"
"@

  $bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.seeds.json"
  try {
    & $bridge -Prompt $instruction -OutFile $tmp -DryRun:$false
    $raw = Get-Content -Raw -Path $tmp
    $arr = $null
    try { $arr = $raw | ConvertFrom-Json -Depth 100 } catch { $arr = $null }
    if ($arr -and $arr.Count -gt 0) {
      foreach ($s in $arr) {
        $obj = @{ seed = $s }
        $newPaths += (Write-SeedFiles -obj $obj -dir $worldsDir)
      }
    } else {
      throw "LLM did not return valid JSON"
    }
  } catch {
    # Fallback path
    1..$Count | ForEach-Object {
      $obj = New-LocalSeed -prompt $Prompt -isekai:$Isekai -dnd:$DndCompat
      $newPaths += (Write-SeedFiles -obj $obj -dir $worldsDir)
    }
  }
} else {
  # No API key or forced fallback
  1..$Count | ForEach-Object {
    $obj = New-LocalSeed -prompt $Prompt -isekai:$Isekai -dnd:$DndCompat
    $newPaths += (Write-SeedFiles -obj $obj -dir $worldsDir)
  }
}

Write-Host "Generated seeds:`n - " + ($newPaths -join "`n - ")
exit 0
