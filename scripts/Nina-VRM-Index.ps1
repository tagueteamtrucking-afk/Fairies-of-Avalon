$root=Split-Path -Parent $PSScriptRoot
$vrmDirs = @('asset/winged-models','asset/models/with-wings','asset/models/wingless','asset/models')
$items=@()
foreach($d in $vrmDirs){
  $p = Join-Path $root $d
  if(Test-Path $p){
    Get-ChildItem -Path $p -Filter *.vrm -File -ErrorAction SilentlyContinue | ForEach-Object {
      $items += @{ path = $_.FullName.Replace($root,"").Replace("\","/").TrimStart("/"); size_bytes = $_.Length; updated = $_.LastWriteTimeUtc.ToString("s") + "Z" }
    }
  }
}
$out = Join-Path $root 'pages/apps/nina/vrm-index.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
[IO.File]::WriteAllText($out, (@{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; items=$items } | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "VRM index -> $out"
