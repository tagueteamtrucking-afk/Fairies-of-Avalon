param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$MaxCombos = 12,
  [string]$World = ""
)
$ErrorActionPreference='Stop'
$overDir = Join-Path $RepoRoot 'data/overseers'
if(!(Test-Path $overDir)){ New-Item -ItemType Directory -Force -Path $overDir | Out-Null }

function List-Files([string]$p,[string]$filter){ if(Test-Path $p){ Get-ChildItem -LiteralPath $p -Filter $filter -File | ForEach-Object { $_.FullName } } else { @() } }

$modelsRoot = Join-Path $RepoRoot 'asset/models'
$wingedRoot = Join-Path $RepoRoot 'asset/winged-models'
$wingsRoot  = Join-Path $RepoRoot 'asset/wings'

$vrms = @()
$vrms += (List-Files $modelsRoot '*.vrm')
$vrms += (List-Files $wingedRoot '*.vrm')

$wingsMeshes = (List-Files $wingsRoot '*.fbx')
$wingsTextures = (List-Files (Join-Path $wingsRoot 'textures') '*.png')

$index = [ordered]@{
  world=$World; generated=(Get-Date).ToUniversalTime().ToString('o');
  vrm_files=$vrms | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  wing_meshes=$wingsMeshes | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  wing_textures=$wingsTextures | ForEach-Object { $_.Substring($RepoRoot.Length).TrimStart('\','/') };
  max_combos=$MaxCombos
}
$path = Join-Path $overDir 'vrm-index.json'
$index | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "VRM index written to $path"
