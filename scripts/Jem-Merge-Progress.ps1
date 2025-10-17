param(
  [string]$LogsDir="pages/apps/jem/logs",
  [string]$Output="pages/apps/jem/programs/progress.json"
)
$root = Split-Path -Parent $PSScriptRoot
$logsAbs = Join-Path $root $LogsDir
$outAbs = Join-Path $root $Output
if(-not (Test-Path $logsAbs)){ New-Item -ItemType Directory -Force -Path $logsAbs | Out-Null }
$entries = @()
$files = Get-ChildItem -Path $logsAbs -Filter "*.json" -File -ErrorAction SilentlyContinue
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
    if($j.person -and $j.week){ $entries += $j }
  }catch{ Write-Warning "Skip invalid JSON: $($f.Name)" }
}
$grouped = @{}
foreach($e in $entries){
  $name = $e.person.name
  if([string]::IsNullOrWhiteSpace($name)){ continue }
  if(-not $grouped.ContainsKey($name)){ $grouped[$name] = @() }
  $grouped[$name] += $e
}
$out = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z';
  persons=@()
}
foreach($k in $grouped.Keys){
  $hist = $grouped[$k] | Sort-Object { $_.updated } -Descending
  $out.persons += @{ name=$k; history=$hist }
}
$dirOut = Split-Path -Parent (Join-Path $root $Output)
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText((Join-Path $root $Output), ($out | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
Write-Host "Merged progress -> $Output"
