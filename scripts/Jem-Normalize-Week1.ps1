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

$map = @{}
if(Test-Path (Join-Path $root $MapFile)){
  try{ $map = Get-Content -Raw -Path (Join-Path $root $MapFile) | ConvertFrom-Json } catch {}
}

# Collect items
$items = @()
foreach($f in $files){
  try{
    $j = Get-Content -Raw -Path $f.FullName | ConvertFrom-Json
  }catch{
    Write-Warning "Invalid JSON: $($f.Name) — skipping"
    continue
  }
  $pname = ($j.person.name | Out-String).Trim()
  $evalTs = $null
  if($pname -match '^Evaluation-(\d{8}T\d{6}Z)$'){ $evalTs = $Matches[1] }
  $items += [pscustomobject]@{ File=$f; Name=$pname; EvalTs=$evalTs; Json=$j }
}

# Determine current presence
$hasRay     = $items | Where-Object { $_.Name -match '^(?i)ray$' } | Select-Object -First 1
$hasBlanca  = $items | Where-Object { $_.Name -match '^(?i)blanca$' } | Select-Object -First 1
$unknowns   = $items | Where-Object { $_.Name -notmatch '^(?i)(ray|blanca)$' }

# If name-map.json is present, apply explicit mapping
$plannedMap = @{}
if($map.PSObject.Properties.Name.Count -gt 0){
  foreach($k in $map.PSObject.Properties.Name){
    $v = [string]$map.$k
    if($v -match '^(?i)(ray|blanca)$'){ $plannedMap[$k] = $v.Substring(0,1).ToUpper()+$v.Substring(1).ToLower() }
  }
}else{
  # Heuristic: if there are two unknowns that look like Evaluation-<ts>, sort by ts and map older->Ray, newer->Blanca (only if needed)
  $evals = $unknowns | Where-Object { $_.EvalTs } | Sort-Object EvalTs
  if(-not $hasRay -and $evals.Count -ge 1){ $plannedMap[$evals[0].Name] = "Ray" }
  if(-not $hasBlanca -and $evals.Count -ge 2){ $plannedMap[$evals[1].Name] = "Blanca" }
}

$changes = @()
foreach($it in $items){
  $oldName = $it.Name
  $targetName = $oldName
  if($plannedMap.ContainsKey($oldName)){ $targetName = $plannedMap[$oldName] }
  # Normalize exact casing for Ray/Blanca
  if($targetName -match '^(?i)ray$'){ $targetName = 'Ray' }
  elseif($targetName -match '^(?i)blanca$'){ $targetName = 'Blanca' }

  $wantRename = $false
  if($targetName -ne $oldName){ $wantRename = $true }
  $desiredFile = Join-Path $dir ("week1-"+$targetName.Replace(' ','_')+".json")
  if($it.File.FullName -ne $desiredFile){ $wantRename = $true }

  if($wantRename){
    $it.Json.person.name = $targetName
    # write to temp then move
    $tmp = $desiredFile + ".tmp"
    [IO.File]::WriteAllText($tmp, ($it.Json | ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
    if(Test-Path $desiredFile){ Remove-Item -Path $desiredFile -Force }
    Move-Item -Path $tmp -Destination $desiredFile -Force
    if(Test-Path $it.File.FullName){ Remove-Item -Path $it.File.FullName -Force }
    $changes += @{ from=$it.File.Name; to=(Split-Path -Leaf $desiredFile); old=$oldName; new=$targetName }
  }
}

# Rebuild index.json (programs only)
$indexPath = Join-Path $dir "index.json"
$allJson = Get-ChildItem -Path $dir -Filter "*.json" -File | ForEach-Object { "programs/"+ $_.Name }
$idx = @{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$allJson }
[IO.File]::WriteAllText($indexPath, ($idx | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)

if($changes.Count -gt 0){
  Write-Host "Normalized:"
  $changes | ForEach-Object { Write-Host (" - "+$_.from+" ["+$_.old+"] -> "+$_.to+" ["+$_.new+"]") }
}else{
  Write-Host "No renames needed."
}
Write-Host "Index rebuilt: programs/index.json"
