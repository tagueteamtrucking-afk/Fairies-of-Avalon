$root=Split-Path -Parent $PSScriptRoot
$wall=Join-Path $root 'asset/textures/wallpapers'
$out=Join-Path $root 'pages/apps/tracy/wallpaper-index.json'
$items=@()
if(Test-Path $wall){
  Get-ChildItem -Path $wall -File -Include *.jpg,*.jpeg,*.png | Sort-Object Name | ForEach-Object {
    $items += @{ path = $_.FullName.Replace($root,"").Replace("\","/").TrimStart("/"); size_bytes = $_.Length; updated = $_.LastWriteTimeUtc.ToString("s") + "Z" }
  }
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
[IO.File]::WriteAllText($out, (@{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; items=$items } | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Wallpaper index -> $out"
