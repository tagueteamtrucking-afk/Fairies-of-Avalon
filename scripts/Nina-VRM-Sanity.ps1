$root=Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'pages/apps/rooms/rooms.json'
$out = Join-Path $root 'pages/apps/nina/vrm-sanity.json'
$j = Get-Content -Raw -Path $configPath | ConvertFrom-Json
$rows = @()
foreach($r in $j.rooms){
  $p = Join-Path $root ($r.vrm.TrimStart('/').Replace('/','\'))
  $exists = Test-Path $p
  $size = 0; $ts = $null
  if($exists){ $fi = Get-Item -Path $p; $size=$fi.Length; $ts=$fi.LastWriteTimeUtc.ToString('s')+'Z' }
  $rows += @{ id=$r.id; name=$r.name; vrm=$r.vrm; exists=$exists; size_bytes=$size; updated=$ts }
}
$outObj = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; rooms=$rows }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
[IO.File]::WriteAllText($out, ($outObj | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "VRM sanity -> $out"
