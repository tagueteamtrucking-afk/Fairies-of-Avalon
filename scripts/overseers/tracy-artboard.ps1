param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [object]$Boards = 8
)
$ErrorActionPreference='Stop'

function As-Int([object]$x,[int]$default){
  if ($null -eq $x) { return $default }
  if ($x -is [int]) { return [int]$x }
  if ($x -is [long]) { return [int]$x }
  if ($x -is [double]) { return [int][Math]::Round($x) }
  if ($x -is [string]) { $s=$x.Trim(); if ($s -eq "") { return $default }; return [int]$s }
  if ($x -is [object[]]) { foreach($e in $x){ if($null -ne $e -and "$e".Trim() -ne ""){ return [int]("$e") } } return $default }
  return [int]("$x")
}

[int]$BoardsI = As-Int $Boards 8

$root = Join-Path $RepoRoot 'pages/apps/tracy/artboards'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
if([string]::IsNullOrWhiteSpace($World)){ $World = "generic" }
$dir = Join-Path $root $World
New-Item -ItemType Directory -Force -Path $dir | Out-Null
for($i=1;$i -le [Math]::Max(1,$BoardsI);$i++){
  $brief = @{ id=("board-"+$i); world=$World; style="futuristic fantasy + sci-fi"; subject=("Key visual "+$i); constraints=@("mobile-first","high contrast","no text"); references=@("vrm-index.json","lore-bible.json","atlas.json") }
  $brief | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $dir ("artboard-"+$i+".json")) -Encoding UTF8
}
Write-Host "Tracy artboards ready for $World"
