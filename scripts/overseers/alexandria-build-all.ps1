param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$Title = "",
  [string]$Prompt = "",
  [int]$Events = 7,
  [int]$NPCs = 12,
  [int]$Regions = 5
)
$ErrorActionPreference='Stop'
function Iso { (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){ return "avalon" } ($s.ToLower() -replace '[^a-z0-9]+','-').Trim('-') }

$dataRoot = Join-Path $RepoRoot 'data/alexandria/worlds'
if(!(Test-Path $dataRoot)){ New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null }

$wid = (Iso) + "-" + (Slug $Title)
$worldDir = Join-Path $dataRoot $wid
New-Item -ItemType Directory -Force -Path $worldDir | Out-Null

# Seed
$seed = [ordered]@{
  id=$wid; title=$Title; prompt=$Prompt; created=(Get-Date).ToUniversalTime().ToString('o');
  regions=$Regions; npc_target=$NPCs; timeline_events=$Events;
  tags=@("isekai","dnd","avalon")
}
$seedPath = Join-Path $worldDir ("seed-"+$wid+".json")
$seed | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $seedPath -Encoding UTF8

# Timeline
$events = @()
for($i=1;$i -le [Math]::Max(1,$Events);$i++){
  $events += @{ idx=$i; title="Event $i"; era= ("Age " + [math]::Ceiling($i/3.0)); summary="Placeholder world event $i." }
}
$timeline = @{ world=$wid; events=$events }
$timeline | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "timeline.json") -Encoding UTF8

# NPC codex
$npc=@()
for($n=1;$n -le [Math]::Max(1,$NPCs);$n++){
  $npc += @{ id=("npc-"+$n); name=("NPC "+$n); role="support"; origin="kingdom"; notes="Placeholder" }
}
$npc | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "npc-codex.json") -Encoding UTF8

# Atlas
$regionsAry=@()
for($r=1;$r -le [Math]::Max(1,$Regions);$r++){
  $regionsAry += @{ id=("region-"+$r); name=("Region "+$r); biomes=@("plains"); settlements=@("Town A","Village B") }
}
$atlas = @{ world=$wid; regions=$regionsAry }
$atlas | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "atlas.json") -Encoding UTF8

# Lore bible (skeleton)
$bible = [ordered]@{
  world=$wid;
  themes=@("hope","sacrifice");
  magic_system=@{ source="mana"; rules=@("conservation","cost"); };
  factions=@(@{ id="crown"; ethos="order" }, @{ id="veil"; ethos="secrets" });
}
$bible | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "lore-bible.json") -Encoding UTF8

# Mark latest
"$wid" | Set-Content -LiteralPath (Join-Path $dataRoot "latest.txt") -Encoding UTF8
Write-Host "World created: $wid"
