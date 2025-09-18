param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [int]$Boards = 8
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'data/tracy/artboards'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
if([string]::IsNullOrWhiteSpace($World)){ $World = "generic" }
$dir = Join-Path $root $World
New-Item -ItemType Directory -Force -Path $dir | Out-Null
for($i=1;$i -le [Math]::Max(1,$Boards);$i++){
  $brief = @{
    id=("board-"+$i); world=$World;
    style="futuristic fantasy + sci-fi";
    subject=("Key visual "+$i);
    constraints=@("mobile-first","high contrast","no text");
  }
  $brief | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $dir ("artboard-"+$i+".json")) -Encoding UTF8
}
Write-Host "Tracy artboards ready for $World"
