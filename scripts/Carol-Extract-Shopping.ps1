param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$OutFile="pages/apps/carol/plans/shopping-extracted.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $root $PlansDir
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending
if(-not $files){ Write-Error "No *.json plans found in $plansAbs"; exit 1 }
$chosen = $files[0]

try{ $j = Get-Content -Raw -Path $chosen.FullName | ConvertFrom-Json }
catch{ Write-Error "Invalid JSON in $($chosen.Name)"; exit 1 }

# Prefer explicit shopping arrays if present
$shopping = @()
if($j.shopping){ $shopping = $j.shopping }
elseif($j.menu -and $j.menu.shopping){ $shopping = $j.menu.shopping }

function Add-Item($list, [string]$name, [double]$qty, [string]$unit){
  if([string]::IsNullOrWhiteSpace($name)){ return }
  if([string]::IsNullOrWhiteSpace($unit)){ $unit = "" }
  $already = $list | Where-Object { $_.name -eq $name -and $_.unit -eq $unit } | Select-Object -First 1
  if($already){ $already.qty += $qty }
  else { $list += ([pscustomobject]@{ name=$name; qty=$qty; unit=$unit }) }
  return $list
}

function Try-Extract-Node([object]$node, [ref]$acc){
  if($null -eq $node){ return }
  if($node -is [pscustomobject] -or $node -is [hashtable]){
    $n = $null; $q = $null; $u = $null
    if($node.PSObject.Properties.Name -contains 'name'){ $n = [string]$node.name }
    foreach($k in @('qty','quantity')){ if($node.PSObject.Properties.Name -contains $k){ $q = [double]$node.$k; break } }
    foreach($k in @('unit','units')){ if($node.PSObject.Properties.Name -contains $k){ $u = [string]$node.$k; break } }
    if($n -and ($q -ne $null)){ $acc.Value = Add-Item -list $acc.Value -name $n -qty $q -unit $u }
    foreach($p in $node.PSObject.Properties){ Try-Extract-Node $p.Value ([ref]$acc.Value) }
  } elseif($node -is [System.Collections.IEnumerable]){
    foreach($x in $node){ Try-Extract-Node $x ([ref]$acc.Value) }
  }
}

if($shopping.Count -eq 0){
  $acc = @()
  Try-Extract-Node $j ([ref]$acc)
  $shopping = $acc
}

$payload = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z';
  source_plan=$chosen.Name;
  count=$shopping.Count;
  items=$shopping
}
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($payload | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Extracted shopping items -> $OutFile (from $($chosen.Name))"
