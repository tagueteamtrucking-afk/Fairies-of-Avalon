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

# Load npc taxonomy and choices for name syllables
$npcTax = $null
$npcPath = Join-Path $RepoRoot "pages/apps/alexandria/knowledge/npc-taxonomy.json"
if (Test-Path $npcPath){ try{ $npcTax = Get-Content -Raw -Path $npcPath | ConvertFrom-Json -Depth 100 }catch{ $npcTax=$null } }
$choices = $null
$choicesPath = Join-Path $RepoRoot "pages/apps/alexandria/knowledge/choices.json"
if (Test-Path $choicesPath) { try { $choices = Get-Content -Raw -Path $choicesPath | ConvertFrom-Json -Depth 100 } catch { $choices = $null } }

function Pick([object[]]$arr){ if(-not $arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }
function Make-Name(){
  if ($choices -and $choices.name_syllables_a -and $choices.name_syllables_b) {
    $a = Pick $choices.name_syllables_a
    $b = Pick $choices.name_syllables_b
    $c = Pick $choices.name_syllables_a
    $n = ($a + $b + $c)
    return ($n.Substring(0,1).ToUpper()+$n.Substring(1))
  }
  $first = @('Aria','Mira','Kael','Ryn','Tessa','Varr','Sol','Nima','Orin','Lysa')
  $last  = @('Lantern','Skystep','Rift','Hollow','Vale','Storm','Umber','Silver','Thorne','Drift')
  return ((Pick $first) + " " + (Pick $last))
}

$count = [Math]::Max(1,[Math]::Min(60,$Count))
$npcs = @()
for($i=0;$i -lt $count;$i++){
  $traits = @()
  if($npcTax -and $npcTax.traits){ $traits = @(@($npcTax.traits) | Get-Random -Count ([Math]::Min(3, @($npcTax.traits).Count))) }
  $npcs += [pscustomobject]@{
    id = "npc-" + ([guid]::NewGuid().ToString().Substring(0,8))
    name = (Make-Name)
    role = if($npcTax){ Pick $npcTax.roles } else { 'Guide' }
    faction = if($seed.factions.Count -ge 1){ Pick @($seed.factions | ForEach-Object { $_.name }) } else { $null }
    traits = $traits
    secret = if($npcTax){ Pick $npcTax.secrets } else { $null }
    motive = if($npcTax){ Pick $npcTax.motives } else { $null }
    alignment = if($npcTax){ Pick $npcTax.alignments } else { $null }
  }
}

$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/codex"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.npcs.json"
$rel  = "/apps/alexandria/worlds/codex/$name"
$codex = [pscustomobject]@{
  id = "npcs-" + (Get-Date -Format 'yyyyMMddHHmmss')
  seed_id = $seed.id
  title = $seed.title
  npcs = $npcs
  generated = Iso
  format_version = "1.0.0"
}
($codex | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir $name) -Encoding utf8NoBOM

# Index
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$codex.id; npcs=$npcs.Count; ts=(Iso) }
($index | ConvertTo-Json -Depth 100) | Set-Content -Path $indexPath -Encoding utf8NoBOM

Write-Host "NPC Codex written: $rel"
exit 0
