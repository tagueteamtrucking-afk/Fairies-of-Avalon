[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$SeedPath="",
  [int]$Count=12,
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){return "world"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$root = (Resolve-Path $RepoRoot).Path
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { throw "No seeds directory found: $worldsDir" }

# Resolve seed file
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

# Load seed
try{ $seed = Get-Content -Raw -Path $seedFile.FullName | ConvertFrom-Json -Depth 100 }catch{ throw "Invalid seed JSON: $($seedFile.FullName)" }

# Deterministic name and attribute pools
$syllA = @('ar','el','is','ka','ly','ma','na','or','ri','sa','ta','va','wyn','zen','dra','sol','mir','the','cor','ane')
$syllB = @('a','e','i','o','u')
function Make-Name{
  $s = ($syllA[(Get-Random -Minimum 0 -Maximum $syllA.Count)]) + ($syllB[(Get-Random -Minimum 0 -Maximum $syllB.Count)]) + ($syllA[(Get-Random -Minimum 0 -Maximum $syllA.Count)])
  return ($s.Substring(0,1).ToUpper()+$s.Substring(1))
}
$roles = @('Guide','Archivist','Gatekeeper','Witch‑Engineer','Ranger‑Navigator','Bard‑Spy','Alchemist‑Medic','Cartographer','Merchant','Zealot','Smuggler','Artificer','Envoy')
$traits= @('pragmatic','idealistic','secretive','stubborn','curious','wry','pious','merciful','calculating','warm','mischievous')
$motives = @('protect kin','unlock forbidden lore','profit','revenge','atonement','prove worth','preserve balance','spark revolution','appease a patron','map the unknown')
$secrets = @('owed blood-debt','stolen sigil','forbidden pact','exiled noble','double agent','astral sickness','false prophecy','lost heir','cursed relic','memory gaps')
$f1 = if($seed.factions.Count -ge 1){ $seed.factions[0].name } else { 'Faction A' }
$f2 = if($seed.factions.Count -ge 2){ $seed.factions[1].name } else { 'Faction B' }
$align = @('LG','NG','CG','LN','N','CN','LE','NE','CE')

# Build NPC list
$npcs = @()
for($i=0;$i -lt $Count; $i++){
  $name = Make-Name
  $role = $roles[(Get-Random -Minimum 0 -Maximum $roles.Count)]
  $fac  = if((Get-Random) % 3 -eq 0) { 'Independent' } else { if((Get-Random) % 2 -eq 0){ $f1 } else { $f2 } }
  $npc = [pscustomobject]@{
    id = "npc-" + [guid]::NewGuid().ToString().Substring(0,8)
    name = $name
    role = $role
    faction = $fac
    alignment = $(if($seed.dnd_compatible){ $align[(Get-Random -Minimum 0 -Maximum $align.Count)] } else { $null })
    tagline = "$role caught between $f1 and $f2."
    motives = @($motives | Get-Random -Count 2)
    secret = $secrets[(Get-Random -Minimum 0 -Maximum $secrets.Count)]
    traits = @($traits | Get-Random -Count 3)
  }
  $npcs += $npc
}

# Optional LLM enrichment (non-fatal)
$bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
if (-not $ForceFallback -and $env:OPENAI_API_KEY -and (Test-Path $bridge)) {
  $prompt = @"
You are Alexandria, building an NPC codex for a setting. For each NPC, write a one-line 'tagline' that hints at conflict, and short phrases for 2 motives and 1 secret.
Return ONLY a JSON array the same length as input, with objects: { "tagline": "...", "motives": ["...","..."], "secret": "..." }.
Seed:
$($seed | ConvertTo-Json -Depth 40)
NPC skeletons:
$([string]::Join("`n", ($npcs | ForEach-Object { "{name:'"+$_.name+"', role:'"+$_.role+"', faction:'"+$_.faction+"'}" } )))
"@
  $tmp = Join-Path $env:RUNNER_TEMP "alexandria.npcs.enriched.json"
  try{
    & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false
    $arr = Get-Content -Raw -Path $tmp | ConvertFrom-Json -Depth 100
    if ($arr -and $arr.Count -eq $npcs.Count){
      for($i=0;$i -lt $npcs.Count; $i++){
        if ($arr[$i].tagline) { $npcs[$i].tagline = [string]$arr[$i].tagline }
        if ($arr[$i].motives) { $npcs[$i].motives = $arr[$i].motives }
        if ($arr[$i].secret)  { $npcs[$i].secret  = [string]$arr[$i].secret }
      }
    }
  }catch{}
}

$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/npcs"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.npcs.json"
$rel  = "/apps/alexandria/worlds/npcs/$name"

$codex = [pscustomobject]@{
  id = "codex-" + (Get-Date -Format 'yyyyMMddHHmmss')
  seed_id = $seed.id
  title = $seed.title
  count = $npcs.Count
  npcs = $npcs
  generated = Iso
  format_version = "1.0.0"
}

($codex | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir $name) -Encoding utf8NoBOM
($codex | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir "latest.json") -Encoding utf8NoBOM

# Update index
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$codex.id; count=$codex.count; ts=(Iso) }
($index | ConvertTo-Json -Depth 100) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "NPC Codex written: $rel"
exit 0
