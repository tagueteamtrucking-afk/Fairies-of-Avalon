param(
  [string]$PlansDir="pages/apps/carol/plans",
  [string]$OutFile="pages/apps/carol/plans/shopping-extracted.json",
  [int]$MaxDepth=30,
  [int]$MaxNodes=5000
)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$plansAbs = Join-Path $root $PlansDir
$outAbs = Join-Path $root $OutFile

if(-not (Test-Path $plansAbs)){ Write-Error "PlansDir not found: $plansAbs"; exit 1 }
$files = Get-ChildItem -Path $plansAbs -File -Filter "*.json" | Sort-Object LastWriteTime -Descending
if(-not $files){ Write-Error "No *.json plans found in $plansAbs"; exit 1 }
$chosen = $files[0]

try{ $j = Get-Content -Raw -Path $chosen.FullName | ConvertFrom-Json } catch { Write-Error "Invalid JSON in $($chosen.Name)"; exit 1 }

$shopping = @()
if($j.shopping){ $shopping = $j.shopping }
elseif($j.menu -and $j.menu.shopping){ $shopping = $j.menu.shopping }

function Add-Item([hashtable]$acc, [string]$name, [double]$qty, [string]$unit){
  if([string]::IsNullOrWhiteSpace($name)){ return }
  $u = if([string]::IsNullOrWhiteSpace($unit)) { "" } else { $unit }
  $key = "$name|$u"
  if(-not $acc.ContainsKey($key)){ $acc[$key] = @{ name=$name; qty=0.0; unit=$u } }
  $acc[$key].qty += $qty
}

function Try-Number([object]$v){
  if($null -eq $v){ return $null }
  if($v -is [double] -or $v -is [int] -or $v -is [decimal]){ return [double]$v }
  $s=[string]$v; $s=$s.Trim()
  if($s -match '^\s*(\d+)\s*/\s*(\d+)\s*$'){ $n=[double]$Matches[1]; $d=[double]$Matches[2]; if($d -ne 0){ return $n/$d } }
  if($s -match '^\s*(\d+)\s+(\d+)\s*/\s*(\d+)\s*$'){ $a=[double]$Matches[1]; $n=[double]$Matches[2]; $d=[double]$Matches[3]; if($d -ne 0){ return $a + ($n/$d) } }
  $out=0.0; if([double]::TryParse($s,[ref]$out)){ return $out }
  return $null
}

if($shopping.Count -eq 0){
  $acc = @{}
  $queue = New-Object System.Collections.Queue
  $queue.Enqueue(@{ node=$j; depth=0 })
  $visited = New-Object System.Collections.Generic.HashSet[string]
  $nodeCount=0

  while($queue.Count -gt 0){
    $pair = $queue.Dequeue()
    $node = $pair.node; $depth=[int]$pair.depth
    if($depth -gt $MaxDepth){ continue }
    $nodeCount++; if($nodeCount -gt $MaxNodes){ break }
    try{
      $sig = ""
      if($node -is [pscustomobject] -or $node -is [hashtable]){ $sig = ($node | ConvertTo-Json -Depth 3) }
      elseif($node -is [System.Collections.IEnumerable] -and -not ($node -is [string]) -and -not ($node -is [byte[]])){ $sig = (@($node) | ConvertTo-Json -Depth 2) }
      else { $sig = [string]$node }
      if(-not [string]::IsNullOrEmpty($sig)){ if($visited.Contains($sig)){ continue } else { $visited.Add($sig) | Out-Null } }
    } catch {}

    if($node -is [pscustomobject] -or $node -is [hashtable]){
      $n=$null;$q=$null;$u=$null
      if($node.PSObject.Properties.Name -contains 'name'){ $n=[string]$node.name }
      foreach($k in @('qty','quantity')){ if($node.PSObject.Properties.Name -contains $k){ $q=Try-Number $node.$k; if($q -ne $null){ break } } }
      foreach($k in @('unit','units')){ if($node.PSObject.Properties.Name -contains $k){ $u=[string]$node.$k; break } }
      if($n -and ($q -ne $null)){ Add-Item -acc $acc -name $n -qty $q -unit $u }

      foreach($p in $node.PSObject.Properties){
        $v=$p.Value
        if($v -is [pscustomobject] -or $v -is [hashtable]){ $queue.Enqueue(@{ node=$v; depth=$depth+1 }) }
        elseif($v -is [System.Collections.IEnumerable] -and -not ($v -is [string]) -and -not ($v -is [byte[]])){
          foreach($e in $v){ if($e -is [pscustomobject] -or $e -is [hashtable]){ $queue.Enqueue(@{ node=$e; depth=$depth+1 }) } }
        }
      }
    } elseif($node -is [System.Collections.IEnumerable] -and -not ($node -is [string]) -and -not ($node -is [byte[]])){
      foreach($e in $node){ if($e -is [pscustomobject] -or $e -is [hashtable]){ $queue.Enqueue(@{ node=$e; depth=$depth+1 }) } }
    }
  }
  $shopping = @()
  foreach($kv in $acc.GetEnumerator()){ $shopping += [pscustomobject]@{ name=$kv.Value.name; qty=[double]$kv.Value.qty; unit=$kv.Value.unit } }
}

$payload = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; source_plan=$chosen.Name; count=$shopping.Count; items=$shopping }
$dirOut = Split-Path -Parent $outAbs
if(-not (Test-Path $dirOut)){ New-Item -ItemType Directory -Force -Path $dirOut | Out-Null }
[IO.File]::WriteAllText($outAbs, ($payload | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Extracted shopping items -> $OutFile (from $($chosen.Name))"
