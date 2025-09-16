[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$ChoicesPath="pages/apps/alexandria/knowledge/choices.json"
)
$ErrorActionPreference='Stop'

function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }

$root = (Resolve-Path $RepoRoot).Path
$choicesFull = Join-Path $RepoRoot $ChoicesPath
if (-not (Test-Path $choicesFull)) { throw "Choices file not found: $ChoicesPath" }

try { $c = Get-Content -Raw -Path $choicesFull | ConvertFrom-Json -Depth 100 } catch { throw "Invalid JSON in $ChoicesPath" }

# Helper: get list or default
function ListOrDefault([object]$obj, [string]$key, [object[]]$def){
  $v = $obj.PSObject.Properties[$key].Value
  if ($null -eq $v) { return $def }
  if ($v -is [array]) { return @($v | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique) }
  return $def
}

# Defaults
$dim = ListOrDefault $c 'dimensions' @('Prime','Fae','Shadow','Astral','Undersea','Clockwork','Dream','Infernal','Celestial','Void')
$time= ListOrDefault $c 'timeflow' @('synchronous','slower','faster','erratic')
$mint= ListOrDefault $c 'magic_intensity' @('low','medium','high','wild','forbidden')
$tech= ListOrDefault $c 'tech_levels' @('stone','medieval','clockwork','industrial','diesel','digital','fusion','mythic')
$gates=ListOrDefault $c 'gate_types' @('natural portal','ritual gate','waystone','mirror','tree-hollow','mist-ferry','starlight bridge','machine arch')
$biom= ListOrDefault $c 'biomes' @('forest','jungle','desert','tundra','alpine','swamp','coast','islands','plains','savanna','steppe','badlands','underdark','floating isles','crystal fields','mushroom woods')
$clim= ListOrDefault $c 'climates' @('polar','cold','temperate','arid','tropical','monsoon','mediterranean','subtropical')
$haz = ListOrDefault $c 'hazards' @('bandits','curse','blight','storms','beasts','undead','toxins','fey tricks','machina failures','quakes','warzone')
$res = ListOrDefault $c 'resources' @('iron','salt','spices','silk','amber','mana-springs','ether-crystals','ancient scripts','myth-wood','skywhale oil','star-metal','holy relics')

$roles = ListOrDefault $c 'professions' @('Guide','Archivist','Gatekeeper','Witch‑Engineer','Ranger‑Navigator','Bard‑Spy','Alchemist‑Medic','Cartographer','Merchant','Zealot','Smuggler','Artificer','Envoy')
$traits= ListOrDefault $c 'traits' @('pragmatic','idealistic','secretive','stubborn','curious','wry','pious','merciful','calculating','warm','mischievous')
$mot   = ListOrDefault $c 'motives' @('protect kin','unlock forbidden lore','profit','revenge','atonement','prove worth','preserve balance','spark revolution','appease a patron','map the unknown')
$sec   = ListOrDefault $c 'secrets' @('owed blood-debt','stolen sigil','forbidden pact','exiled noble','double agent','astral sickness','false prophecy','lost heir','cursed relic','memory gaps')
$aln   = ListOrDefault $c 'alignments' @('LG','NG','CG','LN','N','CN','LE','NE','CE')

$knowledgeDir = Join-Path $RepoRoot "pages/apps/alexandria/knowledge"
New-Item -ItemType Directory -Force -Path $knowledgeDir | Out-Null

# Atlas taxonomy
$atlas = [pscustomobject]@{
  dimension_types = $dim
  timeflow = $time
  magic_intensity = $mint
  tech_levels = $tech
  gate_types = $gates
  biomes = $biom
  climates = $clim
  hazards = $haz
  resources = $res
  updated = (Iso)
}
$atlasPath = Join-Path $knowledgeDir "atlas-taxonomy.json"
($atlas | ConvertTo-Json -Depth 100) | Set-Content -Path $atlasPath -Encoding utf8NoBOM

# NPC taxonomy
$npc = [pscustomobject]@{
  roles   = $roles
  traits  = $traits
  motives = $mot
  secrets = $sec
  alignments = $aln
  updated = (Iso)
}
$npcPath = Join-Path $knowledgeDir "npc-taxonomy.json"
($npc | ConvertTo-Json -Depth 100) | Set-Content -Path $npcPath -Encoding utf8NoBOM

Write-Host "Atlas taxonomy written: $atlasPath"
Write-Host "NPC taxonomy written: $npcPath"
