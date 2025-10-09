param([string]$ZipPath="pages/apps/jem/imports/SamsungHealthExport.zip")
$root=Split-Path -Parent $PSScriptRoot
$in=Join-Path $root $ZipPath
if(-not (Test-Path $in)){ Write-Error "Export zip not found at $ZipPath"; exit 1 }
$work=Join-Path $env:RUNNER_TEMP "shealth"; New-Item -ItemType Directory -Force -Path $work|Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($in,$work,$true)

function ParseCsv($path){ try{ return Import-Csv -Path $path -ErrorAction Stop } catch { return @() } }
$map = @{
  Steps = @("com.samsung.shealth.step_daily_trend.csv","step_daily_trend.csv");
  Sleep = @("com.samsung.shealth.sleep_stage.csv","sleep_stage.csv");
  Heart = @("com.samsung.shealth.heart_rate.csv","heart_rate.csv");
  Weight= @("com.samsung.shealth.weight.csv","weight.csv");
}
$data=@{ steps=@(); sleep=@(); heart=@(); weight=@() }
foreach($k in $map.Keys){
  foreach($candidate in $map[$k]){
    $paths = Get-ChildItem -Recurse -File -Path $work -Filter $candidate -ErrorAction SilentlyContinue
    foreach($p in $paths){ $rows = ParseCsv $p.FullName; if($rows.Count -gt 0){ $data[$k.ToLower()] += $rows } }
  }
}
function Pick($row,$keys){ foreach($k in $keys){ if($row.PSObject.Properties[$k]){ return $row.$k } } return $null }
$series=[ordered]@{ steps=@(); sleep=@(); heart=@(); weight=@() }
foreach($r in $data.steps){ $series.steps += @{ date=Pick $r @("date","day_time","create_time"); steps=[int](Pick $r @("count","step_count","steps")) } }
foreach($r in $data.heart){ $series.heart += @{ time=Pick $r @("start_time","time"); bpm=[int](Pick $r @("heart_rate","bpm","hr")) } }
foreach($r in $data.sleep){ $series.sleep += @{ start=Pick $r @("start_time","start"), end=Pick $r @("end_time","end"), stage=Pick $r @("stage","sleep_stage") } }
foreach($r in $data.weight){ $series.weight += @{ time=Pick $r @("time","start_time"); kg=[double](Pick $r @("weight","value")) } }
$outDir = Join-Path $root 'pages/apps/jem/biometrics'; New-Item -ItemType Directory -Path $outDir -Force|Out-Null
$out = Join-Path $outDir ("import-"+(Get-Date -Format "yyyyMMddTHHmmssZ")+".json")
[IO.File]::WriteAllText($out, (ConvertTo-Json $series -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Parsed Samsung Health -> $out"
