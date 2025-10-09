param([int]$KcalA=1800,[int]$KcalB=1600,[string]$Region="EU",[string]$Pattern="DASH")
$root=Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'pages/apps/carol/plans'; New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$ts=(Get-Date -Format "yyyyMMddTHHmmssZ")
$outFile = Join-Path $outDir ("offline-twoperson-2wk-"+$ts+".json")
function Ev($name,$for,$type,$time,$k,$na,$sug,$fib,$items){@{name=$name;for=$for;type=$type;time_hint=$time;kcal=$k;sodium_mg=$na;added_sugars_g=$sug;fiber_g=$fib;items=$items}}
function It($ing,$q,$u,$n){@{ingredient=$ing;quantity=$q;unit=$u;notes=$n}}
$days=@()
for($d=1;$d -le 14;$d++){
  $events=@()
  $events+=Ev "Greek yogurt (LF) with berries & oats" "Both" "snack" "morning" 220 80 6 4 (@(It "lactose-free greek yogurt" 0.5 "cup" "or plant-based" ; It "berries" 0.5 "cup" "" ; It "rolled oats" 2 "tbsp" ""))
  $events+=Ev "Hummus & carrot sticks" "Both" "snack" "midday" 180 220 1 4 (@(It "hummus" 3 "tbsp" "no cumin" ; It "carrot sticks" 1 "cup" ""))
  $events+=Ev "Tuna salad lettuce wraps" "Both" "mini-meal" "midday" 340 420 2 6 (@(It "canned tuna (in water)" 1 "can" "" ; It "lettuce leaves" 6 "piece" "" ; It "olive oil" 1 "tbsp" "" ; It "celery (minced)" 2 "tbsp" ""))
  $events+=Ev "Cottage cheese (LF) + pineapple" "Both" "snack" "evening" 200 340 8 1 (@(It "lactose-free cottage cheese" 0.5 "cup" "" ; It "pineapple chunks" 0.5 "cup" ""))
  $events+=Ev "Chicken & veg bowl" "Both" "mini-meal" "evening" 420 520 4 7 (@(It "chicken breast (cooked dice)" 5 "oz" "" ; It "brown rice (cooked)" 0.5 "cup" "" ; It "steamed mixed vegetables" 1 "cup" ""))
  $days+=@{ index=$d; day_label="Day $d"; events=$events }
}
$j=@{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'
  region=$Region; pattern=$Pattern; weeks=2
  persons=@(@{id="A";name="Ray";kcal=$KcalA;events_per_day_target="6-8"},@{id="B";name="Blanca";kcal=$KcalB;events_per_day_target="6-8"})
  days=$days
  shopping_lists_2wk=@(@{range="wk1-2";produce=@("berries","carrots","lettuce","celery","pineapple","mixed vegetables");protein=@("canned tuna","chicken breast");dairy=@("lactose-free greek yogurt","lactose-free cottage cheese");pantry=@("rolled oats","olive oil");frozen=@();spices=@()})
  component_prep=@(@{when="Day 1";tasks=@("Cook chicken breasts and dice; portion and freeze","Cook brown rice; portion for 3 days")})
  storage_notes=@("Fridge space limited; prefer frozen proteins/veg; thaw overnight.")
  sources=@(@{type="offline_template";note="Heuristic fallback (approximate macros). Replace with AI plan when connection recovers."})
}
[IO.File]::WriteAllText($outFile, ($j | ConvertTo-Json -Depth 32), [Text.Encoding]::UTF8)
Write-Host "Offline plan -> $outFile"
