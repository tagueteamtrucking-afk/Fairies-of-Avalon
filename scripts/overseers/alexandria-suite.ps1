param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [object]$PerTown = 3
)
$ErrorActionPreference='Stop'

function As-Int([object]$x, [int]$default){
  if ($null -eq $x) { return $default }
  if ($x -is [int]) { return [int]$x }
  if ($x -is [long]) { return [int]$x }
  if ($x -is [double]) { return [int][Math]::Round($x) }
  if ($x -is [string]) { $s=$x.Trim(); if ($s -eq "") { return $default }; return [int]$s }
  if ($x -is [object[]]) {
    foreach($e in $x){ if($null -ne $e -and "$e".Trim() -ne ""){ return [int]("$e") } }
    return $default
  }
  return [int]("$x")
}

[int]$PerTownI = As-Int $PerTown 3

$root = Join-Path $RepoRoot 'pages/apps/alexandria/worlds'
if([string]::IsNullOrWhiteSpace($World)){
  $latest = Join-Path $root "latest.txt"
  if(!(Test-Path $latest)){ throw "No worlds yet. Run alexandria-build-all first." }
  $World = Get-Content -LiteralPath $latest -TotalCount 1
}
$worldDir = Join-Path $root $World
if(!(Test-Path $worldDir)){ throw "World not found: $World" }

# Figures per settlement (placeholder)
$figs=@()
for($i=1;$i -le [Math]::Max(1,$PerTownI);$i++){
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

# Scene seeds (serial/webnovel format)
$scenes=@()
for($s=1;$s -le 10;$s++){ $scenes += @{ id=("scene-"+$s); beat="Setup/Inciting/Rising"; note=("Scene note "+$s) } }
$scenes | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $worldDir "scene-seeds.json") -Encoding UTF8

Write-Host "Helpers done for $World"
