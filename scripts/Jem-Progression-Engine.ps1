param(
  [string]$ProgramsDir="pages/apps/jem/programs",
  [string]$OutDir="pages/apps/jem/programs"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$progAbs = Join-Path $root $ProgramsDir
$outAbs  = Join-Path $root $OutDir

$progressPath = Join-Path $progAbs "progress.json"
if(-not (Test-Path $progressPath)){ Write-Error "progress.json not found in $ProgramsDir. Merge logs first."; exit 1 }
try{ $progress = Get-Content -Raw -Path $progressPath | ConvertFrom-Json } catch { Write-Error "Invalid JSON progress.json"; exit 1 }

$week1Files = Get-ChildItem -Path $progAbs -File -Filter "week1-*.json"
if(-not $week1Files){ Write-Error "No week1-*.json plans found"; exit 1 }

function Next-Plan([object]$wk1,[object]$hist){
  $name = $wk1.person.name
  $avgRpe = 6.0
  $pain = $false
  if($hist.$name){
    $h = $hist.$name
    if($h.avg_rpe){ $avgRpe = [double]$h.avg_rpe }
    if($h.pain_flags){ $pain = [bool]$h.pain_flags }
    if($h.plank_max_s -ge 45){ $wk1.strength_template[0].items | ForEach-Object { if($_.name -like "*plank*"){ $_.reps = "30-40s/side" } } }
    if($h.wall_sit_max_s -ge 45){ $wk1.strength_template[1].items | ForEach-Object { if($_.name -like "*wall*" -or $_.name -like "*sit*"){ $_.reps = "40-50s" } } }
  }
  if($pain){ # conservative
    foreach($d in $wk1.strength_template){ foreach($it in $d.items){ if($it.sets){ $it.sets = [math]::Max(2,[int]$it.sets) } } }
  } elseif($avgRpe -le 5){
    foreach($d in $wk1.strength_template){ foreach($it in $d.items){ if($it.sets){ $it.sets = ([int]$it.sets)+1 } } }
  }
  $wk1.week = 2
  $wk1.updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
  return $wk1
}

# Build histogram by name
$hist = @{}
foreach($p in $progress.persons){
  $hist[$p.name] = @{
    avg_rpe = $p.avg_rpe
    pain_flags = $p.pain_flags
    plank_max_s = $p.tests.plank_max_s
    wall_sit_max_s = $p.tests.wall_sit_max_s
  }
}

foreach($f in $week1Files){
  $wk1 = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
  $next = Next-Plan -wk1 $wk1 -hist $hist
  $outFile = Join-Path $outAbs ("week2-"+$wk1.person.name.Replace(' ','_')+".json")
  [IO.File]::WriteAllText($outFile, ($next | ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
  Write-Host "Wrote $outFile"
}

# update index
$all = Get-ChildItem -Path $progAbs -File -Filter "*.json" | ForEach-Object { "programs/"+$_.Name }
[IO.File]::WriteAllText((Join-Path $progAbs "index.json"), (@{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$all } | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
