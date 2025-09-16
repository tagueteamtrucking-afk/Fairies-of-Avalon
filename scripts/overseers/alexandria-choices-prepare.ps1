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

function ListOrDefault([object]$obj, [string]$key, [object[]]$def){
  $prop = $obj.PSObject.Properties[$key]
  if ($null -eq $prop) { return $def }
  $v = $prop.Value
  if ($null -eq $v) { return $def }
  if ($v -is [array]) { return @($v | Where-Object { $_ -ne $null -and $_ -ne '' } | Select-Object -Unique) }
  return $def
}

$knowledgeDir = Join-Path $RepoRoot "pages/apps/alexandria/knowledge"
New-Item -ItemType Directory -Force -Path $knowledgeDir | Out-Null

# Atlas taxonomy
$atlas = [pscustomobject]@{
  dimension_types = (ListOrDefault $c 'dimensions' @('Prime','Fae','Shadow','Astral','Undersea','Clockwork','Dream','Infernal','Celestial','Void'))
  timeflow = (ListOrDefault $c 'timeflow' @('synchronous','slower','faster','erratic'))
  magic_intensity = (ListOrDefault $c 'magic_intensity' @('low','medium','high','wild','forbidden'))
  tech_levels = (ListOrDefault $c 'tech_levels' @('stone','medieval','clockwork','industrial','diesel','digital','fusion','mythic'))
  gate_types = (ListOrDefault $c 'gate_types' @('natural portal','ritual gate','waystone','mirror','tree-hollow','mist-ferry','starlight bridge','machine arch'))
  biomes = (ListOrDefault $c 'biomes' @('forest','jungle','desert','tundra','alpine','swamp','coast','islands','plains','savanna','steppe','badlands','underdark','floating isles','crystal fields','mushroom woods'))
  climates = (ListOrDefault $c 'climates' @('polar','cold','temperate','arid','tropical','monsoon','mediterranean','subtropical'))
  hazards = (ListOrDefault $c 'hazards' @('bandits','curse','blight','storms','beasts','undead','toxins','fey tricks','machina failures','quakes','warzone'))
  resources = (ListOrDefault $c 'resources' @('iron','salt','spices','silk','amber','mana-springs','ether-crystals','ancient scripts','myth-wood','skywhale oil','star-metal','holy relics'))
  updated = (Iso)
}
($atlas | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $knowledgeDir "atlas-taxonomy.json") -Encoding utf8NoBOM

# NPC taxonomy
$npc = [pscustomobject]@{
  roles   = (ListOrDefault $c 'professions' @('Guide','Archivist','Gatekeeper','Witch‑Engineer','Ranger‑Navigator','Bard‑Spy','Alchemist‑Medic','Cartographer','Merchant','Zealot','Smuggler','Artificer','Envoy'))
  traits  = (ListOrDefault $c 'traits' @('pragmatic','idealistic','secretive','stubborn','curious','wry','pious','merciful','calculating','warm','mischievous'))
  motives = (ListOrDefault $c 'motives' @('protect kin','unlock forbidden lore','profit','revenge','atonement','prove worth','preserve balance','spark revolution','appease a patron','map the unknown'))
  secrets = (ListOrDefault $c 'secrets' @('owed blood-debt','stolen sigil','forbidden pact','exiled noble','double agent','astral sickness','false prophecy','lost heir','cursed relic','memory gaps'))
  alignments = (ListOrDefault $c 'alignments' @('LG','NG','CG','LN','N','CN','LE','NE','CE'))
  updated = (Iso)
}
($npc | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $knowledgeDir "npc-taxonomy.json") -Encoding utf8NoBOM

# Bible taxonomy
$bible = [pscustomobject]@{
  cultures = (ListOrDefault $c 'cultures' @('riverfolk','fae courts'))
  governments = (ListOrDefault $c 'governments' @('council','monarchy','magocracy'))
  currencies = (ListOrDefault $c 'currencies' @('lantern tokens','river marks'))
  religions = (ListOrDefault $c 'religions' @('Lantern Way','First Tree'))
  languages = (ListOrDefault $c 'languages' @('River Cant','Skytrade','Old Lantern'))
  magic_schools = (ListOrDefault $c 'magic_schools' @('ward','weave','bind','alter'))
  magic_costs = (ListOrDefault $c 'magic_costs' @('memory erosion','oath-binding'))
  materials = (ListOrDefault $c 'materials' @('myth-wood','aether glass'))
  color_palettes = (ListOrDefault $c 'color_palettes' @('Amber & Teal','Indigo & Silver'))
  creatures = (ListOrDefault $c 'creatures' @('skywhale','leshy'))
  vehicles = (ListOrDefault $c 'vehicles' @('skyship','river barge'))
  updated = (Iso)
}
($bible | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $knowledgeDir "bible-taxonomy.json") -Encoding utf8NoBOM

# Timeline taxonomy
$timeline = [pscustomobject]@{
  event_tags = (ListOrDefault $c 'event_tags' @('hook','contact','threshold','rival','revelation','climax','resolution'))
  holiday_types = (ListOrDefault $c 'holiday_types' @('harvest','lantern tides','founding day'))
  conflict_types = (ListOrDefault $c 'conflict_types' @('faction dispute','forbidden magic','trade war'))
  updated = (Iso)
}
($timeline | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $knowledgeDir "timeline-taxonomy.json") -Encoding utf8NoBOM

Write-Host "Derived taxonomies written."
