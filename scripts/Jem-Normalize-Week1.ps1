param(
  [string]$ProgramsDir="pages/apps/jem/programs",
  [string]$MapFile="pages/apps/jem/programs/name-map.json"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root $ProgramsDir
if(-not (Test-Path $dir)){ Write-Error "ProgramsDir not found: $dir"; exit 1 }

# Accept both classic and odd filenames, but we only rename week1-* files
$files = Get-ChildItem -Path $dir -Filter "week1-*.json" -File -ErrorAction SilentlyContinue
if(-not $files){ Write-Host "No week1-*.json files to normalize in $dir"; exit 0 }

# Load explicit mapping if any
$explicit = @{}
$mapPath = Join-Path $root $MapFile
if(Test-Path $mapPath){
  try{ $explicit = Get-Content -Raw -Path $mapPath | ConvertFrom-Json } catch { Write-Warning "name-map.json invalid; ignoring" }
}

function Get-PersonName([object]$j){
  if($null -eq $j){ return $null }
  # common layout: j.person.name
  if($j.PSObject.Properties.Name -contains 'person'){
    $p = $j.person
    if($p -is [string]){ return ($p | Out-String).Trim() }
    if($p -is [hashtable] -or $p -is [pscustomobject]){
      if($p.PSObject.Properties.Name -contains 'name'){ return ($p.name | Out-String).Trim() }
    }
  }
  # some generators put top-level name
  if($j.PSObject.Properties.Name -contains 'name'){ return ($j.name | Out-String).Trim() }
  return $null
}
function Set-PersonName([ref]$jsonRef, [string]$name){
  $nm = if([string]::IsNullOrWhiteSpace($name)){"Ray"}else{$name}
  $j = $jsonRef.Value
  if(-not ($j.PSObject.Properties.Name -contains 'person')){
    $j | Add-Member -NotePropertyName person -NotePropertyValue (@{ name = $nm }) -Force
  } else {
    $p = $j.person
    if($p -is [string]){
      $j.person = @{ name = $nm }
    } elseif($p -is [hashtable] -or $p -is [pscustomobject]){
      if(-not ($j.person.PSObject.Properties.Name -contains 'name')){
        $j.person | Add-Member -NotePropertyName name -NotePropertyValue $nm -Force
      } else {
        $j.person.name = $nm
      }
    } else {
      $j.person = @{ name = $nm }
    }
  }
  $jsonRef.Value = $j
}
function Guess-FromFilename([string]$fn){
  if($fn -match '(?i)\bray\b'){ return 'Ray' }
  if($fn -match '(?i)\bblanca\b'){ return 'Blanca' }
  return $null
}
function Safe-Target([string]$t, [string]$fallback='Ray'){
  if([string]::IsNullOrWhiteSpace($t)){ return $fallback }
  return $t
}

# Build candidate list
$cands = @()
foreach($f in $files){
  try{ $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json }
  catch{ Write-Warning "Invalid JSON: $($f.Name) — skipping"; continue }
  $pname = Get-PersonName $j
  $evalTs = $null
  if(($pname|Out-String).Trim() -match '^Evaluation-(\d{8}T\d{6}Z)$'){ $evalTs = $Matches[1] }
  $cands += [pscustomobject]@{ File=$f; Json=$j; Name=$pname; EvalTs=$evalTs }
}

# Determine which targets already present
$haveRay = $cands | Where-Object { $_.Name -match '^(?i)\s*ray\s*$' } | Select-Object -First 1
$haveBlanca = $cands | Where-Object { $_.Name -match '^(?i)\s*blanca\s*$' } | Select-Object -First 1

# Build planned rename map
$planned = @{}
# 1) explicit overrides
foreach($k in $explicit.PSObject.Properties.Name){
  $v = [string]$explicit.$k
  if($v -match '^(?i)(ray|blanca)$'){
    $planned[$k] = ($v.Substring(0,1).ToUpper() + $v.Substring(1).ToLower())
  }
}
# 2) Heuristic for Evaluation-*
$evals = $cands | Where-Object { $_.EvalTs } | Sort-Object EvalTs
if(-not $haveRay -and $evals.Count -ge 1 -and -not $planned.ContainsKey($evals[0].Name)){ $planned[$evals[0].Name] = 'Ray' }
if(-not $haveBlanca -and $evals.Count -ge 2 -and -not $planned.ContainsKey($evals[1].Name)){ $planned[$evals[1].Name] = 'Blanca' }

# Normalize pass
$renamed = @()
foreach($c in $cands){
  $old = ($c.Name | Out-String).Trim()
  $target = $old

  # apply explicit or heuristic
  if($planned.ContainsKey($old)){ $target = $planned[$old] }

  # fallbacks based on filename
  if([string]::IsNullOrWhiteSpace($target)){
    $g = Guess-FromFilename $c.File.Name
    if($g){ $target = $g }
  }

  # if still null/unknown, pick first free slot then Ray
  if([string]::IsNullOrWhiteSpace($target) -or ($target -notmatch '^(?i)(ray|blanca)$')){
    if(-not $haveRay){ $target = 'Ray'; $haveRay = $true }
    elseif(-not $haveBlanca){ $target = 'Blanca'; $haveBlanca = $true }
    else { $target = 'Ray' } # safe default
  }

  # canonicalize casing
  if($target -match '^(?i)ray$'){ $target = 'Ray' }
  if($target -match '^(?i)blanca$'){ $target = 'Blanca' }

  # write back person.name
  Set-PersonName ([ref]$c.Json) $target

  # desired file path
  $san = ($target -replace '[^\w\- ]','').Replace(' ','_')
  $desiredFile = Join-Path $dir ("week1-"+$san+".json")

  # if moving or file name differs, rewrite then move
  $tmp = $desiredFile + ".tmp"
  [IO.File]::WriteAllText($tmp, ($c.Json | ConvertTo-Json -Depth 32), [Text.Encoding]::UTF8)
  if(Test-Path $desiredFile){ Remove-Item -Path $desiredFile -Force }
  Move-Item -Path $tmp -Destination $desiredFile -Force

  # remove old only if it's a different path
  if($c.File.FullName -ne $desiredFile -and (Test-Path $c.File.FullName)){
    Remove-Item -Path $c.File.FullName -Force
  }

  $renamed += ("{0} [{1}] -> {2} [{3}]" -f $c.File.Name, ($old ?? 'null'), (Split-Path -Leaf $desiredFile), $target)
}

# rebuild index.json including all jsons in programs
$indexPath = Join-Path $dir "index.json"
$all = Get-ChildItem -Path $dir -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object { "programs/"+$_.Name }
$idx = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$all }
[IO.File]::WriteAllText($indexPath, ($idx | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)

Write-Host "Renamed/normalized:"
$renamed | ForEach-Object { Write-Host " - $_" }
Write-Host "Rebuilt programs/index.json"
