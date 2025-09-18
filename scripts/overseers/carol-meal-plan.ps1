param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Days = 7,
  [int]$KcalTarget = 2200,
  [ValidateSet("balanced","mediterranean","keto","vegetarian")][string]$DietStyle = "balanced"
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'pages/apps/carol/plans'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }

function Round2($n){ [Math]::Round($n,2,[MidpointRounding]::AwayFromZero) }

# macro splits by style
switch($DietStyle){
  "keto"         { $p=0.25; $f=0.70; $c=0.05 }
  "vegetarian"   { $p=0.22; $f=0.28; $c=0.50 }
  "mediterranean"{ $p=0.20; $f=0.35; $c=0.45 }
  default        { $p=0.25; $f=0.30; $c=0.45 }
}
$gP = [Math]::Round(($KcalTarget * $p)/4,0)
$gF = [Math]::Round(($KcalTarget * $f)/9,0)
$gC = [Math]::Round(($KcalTarget * $c)/4,0)

$meals = @("breakfast","lunch","dinner","snack")
$foods = @{
  protein = @("chicken breast","turkey","tofu","tempeh","eggs","greek yogurt","lentils","black beans","salmon","tuna")
  fat     = @("olive oil","avocado","almonds","walnuts","chia seeds","peanut butter","tahini")
  carb    = @("oats","brown rice","quinoa","sweet potato","whole‑grain bread","banana","berries","beans","yogurt")
  veg     = @("spinach","kale","broccoli","bell pepper","tomato","cucumber","carrot","zucchini","onion","mushrooms")
  fruit   = @("apple","orange","grapes","berries","peach","pear")
}

function Pick($arr){ if(!$arr){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }

$plan = @()
$shopping = [ordered]@{ protein=@{}; carb=@{}; fat=@{}; veg=@{}; fruit=@{} }

for($d=1;$d -le [Math]::Max(1,$Days);$d++){
  $day = @()
  foreach($m in $meals){
    $mainP = Pick $foods.protein
    $mainC = Pick $foods.carb
    $mainF = Pick $foods.fat
    $v1 = Pick $foods.veg
    $v2 = Pick $foods.veg
    $fr = Pick $foods.fruit

    $dish = [ordered]@{
      meal = $m
      items = @($mainP, $mainC, $mainF, $v1, $v2, $fr) | Where-Object { $_ }
      est_macros = @{ protein= $gP/($meals.Count); fat=$gF/($meals.Count); carbs=$gC/($meals.Count) }
      est_kcal = [Math]::Round($KcalTarget/($meals.Count),0)
    }
    $day += $dish

    foreach($k in @("protein","carb","fat","veg","fruit")){
      foreach($i in @($mainP,$mainC,$mainF,$v1,$v2,$fr)){
        if($i){
          if(!$shopping[$k].ContainsKey($i)){ $shopping[$k][$i]=0 }
          $shopping[$k][$i] += 1
        }
      }
    }
  }
  $plan += [ordered]@{ day = $d; meals = $day }
}

$out = [ordered]@{
  created = (Get-Date).ToUniversalTime().ToString('o')
  style   = $DietStyle
  target_kcal = $KcalTarget
  target_macros_g = @{ protein=$gP; fat=$gF; carbs=$gC }
  days    = $plan
  shopping_list = $shopping
}

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("mealplan-" + $DietStyle + "-" + $ts + ".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
