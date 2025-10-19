param([string]$Root=".", [switch]$ArchiveOrphans, [string]$ArchiveDir="scripts/_archive")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$invPath = Join-Path $here "memory-history/repo-inventory.json"
$refPath = Join-Path $here "memory-history/repo-refs.json"
if(-not (Test-Path $invPath)){ Write-Error "Run Repo-Inventory.ps1 first"; exit 1 }
if(-not (Test-Path $refPath)){ Write-Error "Run Repo-Refs-Graph.ps1 first"; exit 1 }
$inv = Get-Content -Raw -Path $invPath | ConvertFrom-Json
$refs = Get-Content -Raw -Path $refPath | ConvertFrom-Json
$allPaths = $inv.files | ForEach-Object { $_.path }
$edges = $refs.edges
$used = New-Object System.Collections.Generic.HashSet[string]
$queue = New-Object System.Collections.Queue
foreach($e in $edges){
  if($e.from -like "*/.github/workflows/*" -and $e.to -like "*/scripts/*.ps1"){
    $used.Add($e.to) | Out-Null
    $queue.Enqueue($e.to)
  }
}
while($queue.Count -gt 0){
  $cur = $queue.Dequeue()
  foreach($e in $edges){
    if($e.from -eq $cur -and $e.to -like "*/scripts/*.ps1"){
      if(-not $used.Contains($e.to)){ $used.Add($e.to) | Out-Null; $queue.Enqueue($e.to) }
    }
  }
}
$allScripts = $allPaths | Where-Object { $_ -like "*/scripts/*.ps1" -and $_ -notlike "*/scripts/_archive/*" }
$orphans = @($allScripts | Where-Object { -not $used.Contains($_) })
$out = @{ updated=(Get-Date).ToUniversalTime().ToString("s")+"Z"; totals=@{ files=$inv.count; scripts=$allScripts.Count; used=$used.Count; orphans=$orphans.Count }; used=[array]$used; orphans=$orphans }
$outPath = Join-Path $here "memory-history/repo-usage-report.json"
$dir = Split-Path -Parent $outPath; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outPath, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
