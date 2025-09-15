[CmdletBinding()]
param([string]$RepoRoot=".", [int]$Count=6)
$ErrorActionPreference='Stop'
# Optional: read world seeds to inspire posts
$seedsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
$topics = @()
if (Test-Path $seedsDir){
  $files = Get-ChildItem $seedsDir -Filter *.json | Select-Object -First 3
  foreach($f in $files){
    try{
      $s = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json -Depth 50
      if ($s.title){ $topics += $s.title }
    }catch{}
  }
}
if ($topics.Count -eq 0){ $topics = @('Avalon worldbuilding','Fairy VRM + wings','Futuristic fantasy') }
$platforms = @('YouTube','TikTok','Instagram','X','Blog')
$posts = @()
1..$Count | ForEach-Object {
  $t = $topics[Get-Random -Maximum $topics.Count]
  $p = $platforms[Get-Random -Maximum $platforms.Count]
  $posts += [pscustomobject]@{
    title = "$t — behind the scenes"
    body  = "Quick look at: $t. What would you add?"
    platform = $p
  }
}
$outDir = Join-Path $RepoRoot "pages/apps/sorcha"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
($posts | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "posts.json") -Encoding utf8NoBOM
Write-Host "Posts written."
exit 0
