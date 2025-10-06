$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root 'pages/apps/jem/programs'
if (-not (Test-Path $dir)) { Write-Host "No Jem programs."; exit 0 }
$bad = @(); $warn=@()
Get-ChildItem -File $dir -Filter *.json | ForEach-Object {
  $j = Get-Content -Raw -Path $_.FullName | ConvertFrom-Json
  if (-not $j.sources -or $j.sources.Count -lt 1) { $bad += @{file=$_.Name; issue="no-sources"} }
  if ($j.microcycles) {
    foreach($mc in $j.microcycles){
      foreach($s in $mc.sessions){
        foreach($b in $s.blocks){ if ($b.minutes -gt 20) { $warn += @{file=$_.Name; issue="block>20min"} } }
      }
    }
  }
}
if ($bad.Count -gt 0) { Write-Error ("Jem validate failed: " + ($bad | ConvertTo-Json -Depth 6)); exit 1 }
Write-Host ("Jem validate OK. Warnings: " + ($warn | ConvertTo-Json -Depth 6))
