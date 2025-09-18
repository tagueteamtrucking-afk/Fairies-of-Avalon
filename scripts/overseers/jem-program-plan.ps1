param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Weeks = 8,
  [int]$DaysPerWeek = 4,
  [ValidateSet("recomp","hypertrophy","strength","fatloss")][string]$Goal = "recomp",
  [ValidateSet("minimal","gym")][string]$Equipment = "minimal"
)
$ErrorActionPreference='Stop'
$root = Join-Path $RepoRoot 'pages/apps/jem/programs'
if(!(Test-Path $root)){ New-Item -ItemType Directory -Force -Path $root | Out-Null }

# templates
$split = switch ($DaysPerWeek) {
  2 {"Upper/Lower"}
  3 {"Full/Upper/Lower"}
  4 {"Upper/Lower/Push/Pull"}
  5 {"UL/Push/Pull/Legs/Full"}
  default {"Full Body"}
}

$catalog = @{
  minimal = @{
    push = @("Push-ups","Pike push-ups","Dips (chairs)","Overhead press (bands)")
    pull = @("Body rows (table)","Band rows","Pull-ups/assisted")
    legs = @("Squats","Split squats","Lunges","Hip hinge (good mornings)","Calf raises")
    core = @("Plank","Hollow hold","Side plank","Dead bug")
    cardio = @("Brisk walk","Jog","Jump rope","Bike")
  }
  gym = @{
    push = @("Bench press","Incline DB press","OHP","Dips")
    pull = @("Barbell row","Lat pulldown","Seated cable row","Face pull")
    legs = @("Back squat","RDL","Leg press","Ham curl","Calf raise")
    core = @("Cable woodchop","Hanging leg raise","Cable crunch")
    cardio = @("Row","Bike","Stair master","Treadmill")
  }
}

$repScheme = switch ($Goal) {
  "strength"   { @{ main="5x5";  assist="3x6-8";  cardio="10-15 min" } }
  "hypertrophy"{ @{ main="3x8-12"; assist="3x10-15"; cardio="10-20 min" } }
  "fatloss"    { @{ main="3x10-12"; assist="3x12-15"; cardio="20-30 min" } }
  default      { @{ main="3x6-10"; assist="3x8-12"; cardio="15-20 min" } }
}

$weeks = @()
for($w=1;$w -le [Math]::Max(1,$Weeks);$w++){
  $days=@()
  for($d=1;$d -le [Math]::Max(1,$DaysPerWeek);$d++){
    $day=[ordered]@{
      day = $d
      focus = @("push","pull","legs","full","core")[($d-1) % 5]
      main = @{
        lift = ($catalog.$Equipment.($day.focus) | Select-Object -First 1)
        scheme = $repScheme.main
      }
      assistance = @{
        lifts = @($catalog.$Equipment.($day.focus) | Select-Object -Skip 1 -First 3)
        scheme = $repScheme.assist
      }
      conditioning = @{
        type = ($catalog.$Equipment.cardio | Select-Object -First 1)
        duration = $repScheme.cardio
      }
      notes = "RPE 7-8 on last set; deload if fatigue accumulates."
    }
    $days += $day
  }
  $weeks += [ordered]@{ week=$w; days=$days }
}

$out = [ordered]@{
  created = (Get-Date).ToUniversalTime().ToString('o')
  goal = $Goal
  equipment = $Equipment
  split = $split
  weeks = $weeks
}

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$path = Join-Path $root ("program-" + $Goal + "-" + $Equipment + "-" + $ts + ".json")
$out | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Wrote $path"
