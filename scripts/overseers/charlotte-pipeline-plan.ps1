param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$World = "",
  [string]$TargetLangs = "es"
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'pages/apps/charlotte/pipelines'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }
if([string]::IsNullOrWhiteSpace($World)){ $World="generic" }
$dir = Join-Path $root $World
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$langs = $TargetLangs.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$plan = [ordered]@{
  world=$World; created=(Get-Date).ToUniversalTime().ToString('o');
  tts_tasks=@(@{ id="opening"; ssml="<speak>Welcome to "+$World+"</speak>"});
  translations=@($langs | ForEach-Object { @{ lang=$_; files=@("lore-bible.json","timeline.json") }})
}
$plan | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $dir "plan.json") -Encoding UTF8
Write-Host "Charlotte pipeline plan ready for $World"
