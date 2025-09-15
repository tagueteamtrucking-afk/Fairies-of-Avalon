[CmdletBinding()]
param([string]$RepoRoot=".", [string]$Goal="balanced", [switch]$ForceFallback)
$ErrorActionPreference='Stop'
$days = @('Mon','Tue','Wed','Thu','Fri','Sat','Sun')
$templates = @{
  balanced = @{ breakfast='oats + berries'; lunch='grilled chicken + quinoa + greens'; dinner='salmon + sweet potato + broccoli'; snack='greek yogurt + nuts' }
  lowcarb  = @{ breakfast='eggs + avocado'; lunch='steak salad'; dinner='chicken + zucchini noodles'; snack='cottage cheese' }
  highprotein = @{ breakfast='protein smoothie'; lunch='turkey bowl'; dinner='tofu stir fry'; snack='jerky + apple' }
}
$pick = if($templates.ContainsKey($Goal)) { $Goal } else { 'balanced' }
$plan = @{
  generated = (Get-Date).ToUniversalTime().ToString("s") + 'Z'
  goal = $pick
  days = @{}
}
foreach($d in $days){ $plan.days[$d] = $templates[$pick] }
$outDir = Join-Path $RepoRoot "pages/apps/carol"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
($plan | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "mealplan.json") -Encoding utf8NoBOM
Write-Host "Meal plan written."
exit 0
