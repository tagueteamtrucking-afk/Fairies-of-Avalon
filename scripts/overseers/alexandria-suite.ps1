param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [int]$PerTown = 3
)
$ErrorActionPreference='Stop'
$dataRoot = Join-Path $RepoRoot 'data/alexandria/worlds'
if([string]::IsNullOrWhiteSpace($World)){
  $latest = Join-Path $dataRoot "latest.txt"
  if(!(Test-Path $latest)){ throw "No worlds yet. Run alexandria-build-all first." }
  $World = Get-Content -LiteralPath $latest -TotalCount 1
}
$worldDir = Join-Path $dataRoot $World
if(!(Test-Path $worldDir)){ throw "World not found: $World" }

# Figures per settlement (placeholder)
$figs=@()
for($i=1;$i -le [Math]::Max(1,$PerTown);$i++){
  $figs += @{ name=("Notable "+$i); profession="innkeeper"; hook="Rumor about ancient ruin." }
}
$figs | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "notable-figures.json") -Encoding UTF8

# Continuity checklist
$continuity = @(
  "Consistent dates between timeline and NPC backstories",
  "Magic rules applied uniformly",
  "Factions’ motives show in regional quests"
)
$continuity | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $worldDir "continuity-checklist.json") -Encoding UTF8

# Scene seeds (for serial/webnovel format)
$scenes=@()
for($s=1;$s -le 10;$s++){ $scenes += @{ id=("scene-"+$s); beat="Setup/Inciting/Rising"; note=("Scene note "+$s) } }
$scenes | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "scene-seeds.json") -Encoding UTF8

Write-Host "Helpers done for $World"
