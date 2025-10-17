param(
  [string]$ProgramsDir="pages/apps/jem/programs",
  [string]$MapFile="pages/apps/jem/programs/name-map.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root $ProgramsDir
if(-not (Test-Path $dir)){ Write-Error "ProgramsDir not found: $dir"; exit 1 }

$files = Get-ChildItem -Path $dir -Filter "week1-*.json" -File -ErrorAction SilentlyContinue
if(-not $files){ Write-Host "No week1-*.json files to normalize in $dir"; exit 0 }

# Load optional explicit map
$explicit = @{}
$mapPath = Join-Path $root $MapFile
if(Test-Path $mapPath){
  try{ $explicit = Get-Content -Raw -Path $mapPath | ConvertFrom-Json } catch { Write-Warning "name-map.json invalid; ignoring" }
}

function Get-PersonName([object]$j){
  if($null -eq $j){ return $null }
  if($j.PSObject.Properties.Name -contains 'person'){
    $p = $j.person
    if($p -is [string]){ return $p }
    if($p -is [hashtable] -or $p -is [pscustomobject]){
      if($p.PSObject.Properties.Name -contains 'name'){ return [string]$p.name }
    }
  }
  # fallbacks: look for top-level 'name'
  if($j.PSObject.Properties.Name -contains 'name'){ return [string]$j.name }
  return $null
}

function Set-PersonName([ref]$jsonRef, [string]$name){
  $j = $jsonRef.Value
  if(-not ($j.PSObject.Properties.Name -contains 'person')){
    $j | Add-Member -NotePropertyName person -NotePropertyValue (@{ name = $name }) -Force
  } else {
    $p = $j.person
    if($p -is [string]){
      $j.person = @{ name = $name }
    } elseif($p -is [hashtable] -or $p -is [pscustomobject]){
      if(-not ($j.person.PSObject.Properties.Name -contains 'name')){
        $j.person | Add-Member -NotePropertyName name -NotePropertyValue $name -Force
      } else {
        $j.person.name = $name
      }
    } else {
      $j.person = @{ name = $name }
    }
  }
  $jsonRef.Value = $j
}

# Collect candidates
$cands = @()
foreach($f in $files){
  try{ $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json }
  catch{ Write-Warning "Invalid JSON: $($f.Name) — skipping"; continue }
  $pname = Get-PersonName $j
  $evalTs = $null
  if($pname -match '^Evaluation-(\d{8}T\d{6}Z)$'){ $evalTs = $Matches[1] }
  $cands += [pscustomobject]@{ File=$f; Json=$j; Name=$pname; EvalTs=$evalTs }
}

# Decide mapping
$renames = @()
$haveRay    = $cands | Where-Object { $_.Name -match '^(?i)ray$' } | Select-Object -First 1
$haveBlanca = $cands | Where-Object { $_.Name -match '^(?i)blanca$' } | Select-Object -First 1

$byEval = $cands | Where-Object { $_.EvalTs } | Sort-Object EvalTs
if(-not $haveRay -and $byEval.Count -ge 1){ $renames += @{ old=$byEval[0].Name; new='Ray' } }
if(-not $haveBlanca -and $byEval.Count -ge 2){ $renames += @{ old=$byEval[1].Name; new='Blanca' } }

# Apply explicit map overrides
foreach($k in $explicit.PSObject.Properties.Name){
  $v = [string]$explicit.$k
  if($v -match '^(?i)(ray|blanca)$'){
    $renames = $renames | Where-Object { $_.old -ne $k }
    $renames += @{ old=$k; new=($v.Substring(0,1).ToUpper()+$v.Substring(1).ToLower()) }
  }
}

# Execute renames
$changed = @()
foreach($c in $cands){
  $target = $c.Name
  $mapHit = $renames | Where-Object { $_.old -eq $c.Name } | Select-Object -First 1
  if($mapHit){ $target = $mapHit.new }
  if($target -match '^(?i)ray$'){ $target = 'Ray' }
  elseif($target -match '^(?i)blanca$'){ $target = 'Blanca' }

  $need = $false
  if($null -eq $c.Name){ $need = $true }
  elseif($target -ne $c.Name){ $need = $true }

  $desiredFile = Join-Path $dir ("week1-"+$target.Replace(' ','_')+".json")
  if($c.File.FullName -ne $desiredFile){ $need = $true }

  if($need){
    Set-PersonName ([ref]$c.Json) $target
    $tmp = $desiredFile + ".tmp"
    [IO.File]::WriteAllText($tmp, ($c.Json | ConvertTo-Json -Depth 16), [Text.Encoding]::UTF8)
    if(Test-Path $desiredFile){ Remove-Item -Path $desiredFile -Force }
    Move-Item -Path $tmp -Destination $desiredFile -Force
    if(Test-Path $c.File.FullName){ Remove-Item -Path $c.File.FullName -Force }
    $changed += ("{0} [{1}] -> {2} [{3}]" -f $c.File.Name, ($c.Name ?? 'null'), (Split-Path -Leaf $desiredFile), $target)
  }
}

# Rebuild index.json to include all *.json in programs
$indexPath = Join-Path $dir "index.json"
$all = Get-ChildItem -Path $dir -Filter "*.json" -File | ForEach-Object { "programs/"+$_.Name }
$idx = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$all }
[IO.File]::WriteAllText($indexPath, ($idx | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)

if($changed.Count){ Write-Host "Normalized:`n - " + ($changed -join "`n - ") } else { Write-Host "No renames needed." }
Write-Host "Rebuilt programs/index.json"
