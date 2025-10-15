param(
  [string]$InputDir="pages/apps/jem/intake",
  [string]$OutputDir="pages/apps/jem/programs"
)
$root = Split-Path -Parent $PSScriptRoot
$inAbs = Join-Path $root $InputDir
$outAbs = Join-Path $root $OutputDir
if(-not (Test-Path $inAbs)){ New-Item -ItemType Directory -Force -Path $inAbs | Out-Null }
if(-not (Test-Path $outAbs)){ New-Item -ItemType Directory -Force -Path $outAbs | Out-Null }

# load combined or individual intakes
$persons = @()
$both = Join-Path $inAbs 'intake-both.json'
if(Test-Path $both){
  try{ $j = Get-Content -Raw -Path $both | ConvertFrom-Json; if($j.persons){ $persons = $j.persons } } catch {}
}
if($persons.Count -eq 0){
  foreach($p in @('Ray','Blanca')){
    $f = Join-Path $inAbs "$p-intake.json"
    if(Test-Path $f){ try{ $persons += (Get-Content -Raw -Path $f | ConvertFrom-Json) } catch {} }
  }
}

if($persons.Count -eq 0){ Write-Error "No intake files found in $inAbs"; exit 1 }

function New-BaselineBlock([string]$name, [hashtable]$prefs){
  @{
    name=$name;
    week=1;
    focus=@("knees","back","core");
    constraints=@("limited space","no gym","truck cab");
    sessions_per_week=5;
    max_session_min=20;
    tests=@(
      @{ id="sit_to_stand_30s"; instructions="From a chair, arms crossed, count stands in 30s."; safety="pain-free depth only"; },
      @{ id="plank_hold"; instructions="Forearm plank; record max comfortable hold time."; safety="stop if low back pain"; },
      @{ id="wall_sit"; instructions="Back to wall, hips above knee line; record hold time."; safety="stop if knee pain"; },
      @{ id="step_up_8in"; instructions="Use a stable low step (or improvise safely); 10 reps/leg, record RPE."; safety="avoid knee pinch"; }
    );
    daily_mobility=@(
      "Cat-camel 2×8 slow",
      "Quadruped rock-back 2×10 (hip hinge groove)",
      "Ankle dorsiflexion wall drill 2×8/side",
      "Thoracic open-book 2×6/side",
      "Box breathing 3×1 min"
    );
    strength_template=@(
      @{ day="A"; items=@(
        @{ name="Sit-to-stand to box"; sets=3; reps="8-10"; tempo="32X0"; rest_s="60"; notes="Pain-free depth; add pause to progress." },
        @{ name="Heel-elev goblet squat (no weight ok)"; sets=3; reps="6-8"; rest_s="75"; notes="Small ROM; focus on knee tracking." },
        @{ name="Split-stance hip hinge (stick)"; sets=3; reps="8/side"; rest_s="60"; notes="Glute & ham clean hinge; neutral back." },
        @{ name="Side plank (knees)"; sets=3; reps="20-30s/side"; rest_s="45"; }
      )},
      @{ day="B"; items=@(
        @{ name="Step-ups low"; sets=3; reps="8/side"; rest_s="60"; notes="Use very low, stable surface." },
        @{ name="Glute bridge"; sets=3; reps="10-12"; rest_s="60"; },
        @{ name="Bird-dog"; sets=3; reps="8/side pause 2s"; rest_s="45"; },
        @{ name="Pallof press (band optional)"; sets=3; reps="8/side"; rest_s="45"; notes="If no band, do dead bug 3×8." }
      )}
    );
    conditioning=@("5–10 min easy walk or marching in place, RPE 4–5/10");
    rpe_scale="Use RPE 4–7. Stop on sharp pain.";
    notes=@("Hydrate","Short sessions > no sessions","Record times and RPE in log");
  }
}

function Macro-Reco([double]$wt_lb){
  $wt_kg = $wt_lb * 0.45359237
  $protein = [math]::Round([math]::Max(1.2*$wt_kg, 80),0)  # g/day (1.2 g/kg min, floor 80g)
  @{ kcal_adjust= -250; protein_g=$protein }
}

$index = @()
foreach($p in $persons){
  $name = $p.name
  if(-not $name){ continue }
  $pref = @{
    weight_lb = [double]$p.weight_lb
    schedule = $p.schedule
    issues = $p.issues
    contraindications = $p.contraindications
  }
  $plan = New-BaselineBlock -name $name -prefs $pref
  $plan.updated = (Get-Date).ToUniversalTime().ToString('s')+'Z'
  $plan.person = @{ name=$name; height_in=$p.height_in; weight_lb=$p.weight_lb; age=$p.age }
  $plan.nutrition = Macro-Reco -wt_lb ([double]$p.weight_lb)
  $outFile = Join-Path $outAbs ("week1-"+$name.Replace(' ','_')+".json")
  [IO.File]::WriteAllText($outFile, ($plan | ConvertTo-Json -Depth 10), [Text.Encoding]::UTF8)
  $index += "programs/"+[IO.Path]::GetFileName($outFile)
}

# nutrition handoff for Carol
$handoff = @{
  updated=(Get-Date).ToUniversalTime().ToString('s')+'Z';
  persons=@()
}
foreach($p in $persons){
  $macro = Macro-Reco -wt_lb ([double]$p.weight_lb)
  $handoff.persons += @{ name=$p.name; kcal_delta=$macro.kcal_adjust; protein_g=$macro.protein_g }
}
[IO.File]::WriteAllText((Join-Path $outAbs 'nutrition-adjustments.json'), ($handoff | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)

# programs index
[IO.File]::WriteAllText((Join-Path $outAbs 'index.json'), (@{ updated=(Get-Date).ToUniversalTime().ToString('s')+'Z'; files=$index } | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Week 1 plans written to $outAbs and nutrition handoff created."
