param([string]$Region="US")
$root=Split-Path -Parent $PSScriptRoot
$plansDir = Join-Path $root 'pages/apps/carol/plans'
$idxPath  = Join-Path $plansDir 'index.json'
if(-not (Test-Path $idxPath)){ Write-Error "index.json not found in $plansDir"; exit 1 }
$idx = Get-Content -Raw -Path $idxPath | ConvertFrom-Json
if(-not $idx.files -or $idx.files.Count -eq 0){ Write-Error "No plan files listed"; exit 1 }
$planPath = Join-Path $plansDir $idx.files[0]
$plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json

# load package map
$pkgPath = Join-Path $root "pages/apps/carol/packages/us.json"
if ($Region -eq "EU") { $pkgPath = Join-Path $root "pages/apps/carol/packages/eu.json" }
if (-not (Test-Path $pkgPath)) { Write-Warning "Package map $pkgPath not found; using US defaults"; $pkgPath = Join-Path $root "pages/apps/carol/packages/us.json" }
$pkg = Get-Content -Raw -Path $pkgPath | ConvertFrom-Json

# unit conversions
$toFlOz = @{ tsp=0.1666667; tbsp=0.5; cup=8; "fl oz"=1; floz=1 }
$toTsp  = @{ tsp=1; tbsp=3; cup=48 }
# Weights (approx): PB 1 tbsp ≈ 16 g ≈ 0.56 oz; hummus 1 tbsp ≈ 14 g ≈ 0.49–0.5 oz
$toOzWeight = @{ tbsp_pb=0.56; tbsp_hummus=0.5; tbsp_chia=0.42; tbsp_flax=0.25; cup_oats=2.82; "oz"=1; g=0.035274 }

function Add-Qty([hashtable]$m, [string]$key, [double]$val) { if(-not $m.ContainsKey($key)){ $m[$key]=0.0 } $m[$key]+=[double]$val }

# 1) Aggregate by ingredient
$agg = @{}
foreach($d in $plan.days){
  foreach($ev in $d.events){
    foreach($it in $ev.items){
      $name = ($it.ingredient | Out-String).Trim()
      $qty = [double]$it.quantity
      $unit = ($it.unit | Out-String).Trim().ToLower()
      if(-not $qty){ continue }
      # Normalize similar items (simple heuristics)
      $norm = $name.ToLower()
      if($norm -like "*greek yogurt*"){ $norm = "lactose-free greek yogurt" }
      if($norm -like "*yogurt*" -and $norm -notlike "*greek*"){ $norm = "lactose-free greek yogurt" }
      if($norm -like "*cottage*"){ $norm = "lactose-free cottage cheese" }
      if($norm -like "*mozzarella*"){ $norm = "lactose-free mozzarella" }
      if($norm -like "*milk*"){ $norm = "lactose-free milk" }
      if($norm -like "*black beans*"){ $norm = "low-sodium black beans (rinsed)" }
      if($norm -like "*diced tomatoes*"){ $norm = "diced tomatoes (no salt added)" }
      if($norm -like "*tomato soup*"){ $norm = "low-sodium tomato soup" }
      if($norm -like "*lentil soup*"){ $norm = "low-sodium lentil soup" }
      if($norm -like "*brown rice*" -and $norm -like "*pouch*"){ $norm = "brown rice (microwave pouch)" }
      if($norm -like "*mixed vegetables*"){ $norm = "frozen mixed vegetables" }
      if($norm -like "*frozen mixed berries*" -or $norm -like "*mixed berries*"){ $norm = "frozen mixed berries" }
      if($norm -like "*chia*"){ $norm = "chia seeds" }
      if($norm -like "*flax*"){ $norm = "ground flaxseed" }
      if($norm -like "*tortilla*"){ $norm = "soft whole-wheat tortilla" }
      if($norm -like "*bread*"){ $norm = "soft whole-grain bread" }
      if($norm -like "*egg*"){ $norm = "eggs" }
      if($norm -like "*tuna*"){ $norm = "canned tuna (in water)" }
      if($norm -like "*chicken*" -and $norm -like "*can*"){ $norm = "canned chicken" }
      if($norm -like "*crackers*"){ $norm = "low-sodium crackers" }
      if($norm -like "*pita*"){ $norm = "soft pita" }
      if($norm -like "*potato*"){ $norm = "baby potatoes" }
      if($norm -like "*hummus*"){ $norm = "hummus (no cumin)" }

      $key = $norm
      if(-not $agg.ContainsKey($key)){ $agg[$key] = @{ qty=0.0; unit=$unit } }

      # Convert to canonical where possible
      switch -regex ($key){
        "lactose-free milk|soup|tomatoes" {
          # convert to fl_oz
          $fl = 0.0
          if($toFlOz.ContainsKey($unit)) { $fl = $qty * $toFlOz[$unit] }
          elseif($unit -eq "cup(s)") { $fl = $qty * 8 }
          elseif($unit -eq "oz" -or $unit -eq "fl oz") { $fl = $qty }
          else { $fl = $qty }
          $agg[$key].qty += $fl; $agg[$key].unit = "fl_oz"
        }
        "peanut butter|hummus|greek yogurt|cottage|mozzarella|chia seeds|ground flaxseed|rolled oats|granola|frozen|beans|chicken|tuna|rice pouch|crackers|bread|tortilla|pita|eggs|potatoes|turkey|salmon|cod" {
          # approximate conversions to oz weight for some units
          $oz = 0.0
          if($unit -eq "oz"){ $oz = $qty }
          elseif($unit -eq "tbsp"){
            if($key -like "*peanut butter*"){ $oz = $qty * $toOzWeight["tbsp_pb"] }
            elseif($key -like "*hummus*"){ $oz = $qty * $toOzWeight["tbsp_hummus"] }
            elseif($key -like "*chia*"){ $oz = $qty * $toOzWeight["tbsp_chia"] }
            elseif($key -like "*flax*"){ $oz = $qty * $toOzWeight["tbsp_flax"] }
            else { $oz = $qty * 0.5 }
          }
          elseif($unit -eq "cup"){
            if($key -like "*rolled oats*"){ $oz = $qty * $toOzWeight["cup_oats"] }
            else { $oz = $qty * 8 }
          }
          elseif($unit -eq "piece" -or $unit -eq "slice" -or $unit -eq "count"){ $agg[$key].qty += $qty; $agg[$key].unit = "count"; continue }
          else { $oz = $qty }
          $agg[$key].qty += $oz; $agg[$key].unit = ($agg[$key].unit -eq "count") ? "count" : "oz"
        }
        default {
          $agg[$key].qty += $qty; $agg[$key].unit = $unit
        }
      }
    }
  }
}

# 2) Quantize by package sizes + friendly hints
$buy = @()
foreach($name in $agg.Keys){
  $qty = [double]$agg[$name].qty
  $unit = $agg[$name].unit
  $pack = $pkg.packages | Select-Object -ExpandProperty $name -ErrorAction SilentlyContinue
  $hint = $null
  if($name -like "*peanut butter*" -and $unit -ne "oz"){ $hint = "PB ~0.56 oz per tbsp" }
  if($name -like "*hummus*" -and $unit -ne "oz"){ $hint = "Hummus ~0.5 oz per tbsp" }
  if(-not $pack){
    $buy += @{ ingredient=$name; needed=[math]::Round($qty,2); unit=$unit; suggestion="(no package map — buy to cover need)"; hint=$hint }
    continue
  }
  $punit = $pack.unit
  $packs = @($pack.packs)
  if($unit -ne $punit -and $unit -ne "count"){
    if(($unit -eq "fl_oz" -and $punit -eq "oz") -or ($unit -eq "oz" -and $punit -eq "fl_oz")){
      # treat roughly equivalent for packaged pantry items
      $qty = $qty
    }
  }
  $remain = $qty; $chosen = @()
  $packsSorted = $packs | Sort-Object -Descending
  foreach($sz in $packsSorted){
    if($remain -le 0){ break }
    $n = [math]::Floor($remain / [double]$sz)
    if($n -lt 1){ continue }
    $chosen += @{ size=$sz; count=$n }
    $remain -= $n * [double]$sz
  }
  if($remain -gt 0){ $chosen += @{ size=($packsSorted | Select-Object -Last 1); count=1 } }
  $buy += @{ ingredient=$name; needed=[math]::Round($qty,2); unit=$punit; packages=$chosen; hint=$hint }
}

$out = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z';
  region=$Region;
  items=$buy | Sort-Object ingredient
}
$outPath = Join-Path $plansDir 'shopping-quantized.json'
[IO.File]::WriteAllText($outPath, ($out | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
Write-Host "Quantized shopping -> $outPath"
