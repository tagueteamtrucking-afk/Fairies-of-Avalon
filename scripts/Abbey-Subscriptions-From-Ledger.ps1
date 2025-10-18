param(
  [string]$Ledger="pages/apps/abbey/ledger.json",
  [string]$OutFile="pages/apps/abbey/subscriptions.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$ledAbs = Join-Path $root $Ledger
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $ledAbs)){ Write-Error "Ledger not found at $ledAbs"; exit 1 }
try{ $j = Get-Content -Raw -Path $ledAbs | ConvertFrom-Json } catch { Write-Error "Invalid JSON ledger"; exit 1 }

# Heuristic grouping by vendor tokens, detect monthly/weekly patterns
$groups = @{}
foreach($row in $j.rows){
  $vend = [string]$row.vendor
  # normalize vendor: remove digits and extra spaces
  $vend = ($vend -replace '\d','').Trim()
  if([string]::IsNullOrWhiteSpace($vend)){ continue }
  if(-not $groups.ContainsKey($vend)){ $groups[$vend] = @() }
  $groups[$vend] += [double]$row.amount
}

$subs = @()
foreach($k in $groups.Keys){
  $arr = $groups[$k]
  if($arr.Count -ge 2){
    $avg = [math]::Round(($arr | Measure-Object -Average | Select-Object -Expand Average),2)
    $subs += @{ vendor=$k; amount=$avg; periodicity="recurring?"; count=$arr.Count }
  }
}

$out = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; subscriptions=$subs }
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Subscriptions -> $OutFile with $($subs.Count) entries"
