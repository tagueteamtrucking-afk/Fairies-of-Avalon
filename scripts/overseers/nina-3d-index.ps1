param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [object]$MaxCombos = 12,
  [string]$World = ""
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

[int]$MaxCombosI = As-Int $MaxCombos 12

function List-Files([string]$p,[string]$filter){ if(Test-Path $p){ Get-ChildItem -LiteralPath $p -Filter $filter -File | ForEach-Object { $_.FullName } } else { @() } }

$modelsRoot = Join-Path $RepoRoot 'asset/models'
$wingedRoot = Join-Path $RepoRoot 'asset/winged-models'
$wingsRoot  = Join-Path $RepoRoot 'asset/wings'

$vrms = @(); $vrms += (List-Files $modelsRoot '*.vrm'); $vrms += (List-Files $wingedRoot '*.vrm')
$wingsMeshes = (List-Files $wingsRoot '*.fbx')
$wingsTextures = (List-Files (Join-Path $wingsRoot 'textures') '*.png')

$outDir = Join-Path $RepoRoot 'pages/apps/overseers'
if(!(Test-Path $outDir)){ New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$index = [ordered]@{
  world=$World; generated=(Get-Date).ToUniversalTime().ToString('o');
  vrm_files=$vrms | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  wing_meshes=$wingsMeshes | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  wing_textures=$wingsTextures | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  max_combos=$MaxCombosI
}
$path = Join-Path $outDir 'vrm-index.json'
$index | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "VRM index written to $path"
