param([string]$PlanFile="")
$root = Split-Path -Parent $PSScriptRoot
$plans = Join-Path $root 'pages/apps/carol/plans'
if (-not $PlanFile -or -not (Test-Path $PlanFile)) {
  $latest = Get-ChildItem -Path $plans -Filter *.json -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { Write-Error "No plan JSON found in $plans"; exit 1 }
  $PlanFile = $latest.FullName
}
$j = Get-Content -Raw -Path $PlanFile | ConvertFrom-Json

$exportDir = Join-Path $root 'pages/apps/carol/exports'
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
$ts = Get-Date -Format "yyyyMMddTHHmmssZ"
$html = Join-Path $exportDir ("carol-plan-"+$ts+".html")
$pdf  = Join-Path $exportDir ("carol-plan-"+$ts+".pdf")

$style = @"
<style>
body{font-family:system-ui,Segoe UI,Roboto,Helvetica,Arial;line-height:1.35}
h1,h2{margin:0.2rem 0}
.section{margin:1rem 0}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #ccc;padding:6px;font-size:12px;vertical-align:top}
small{color:#555}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px}
.card{border:1px solid #ccc;padding:8px;border-radius:6px}
</style>
"@
$head = "<h1>Carol — Plan Export</h1><small>Generated: $($j.updated) • Region: $($j.region) • Pattern: $($j.pattern) • Weeks: $($j.weeks)</small>"

$lists = ""
foreach($blk in $j.shopping_lists_2wk){
  $lists += "<div class='card'><h3>Shopping ($($blk.range))</h3>"
  foreach($k in "produce","protein","dairy","pantry","frozen","spices"){
    $arr = $blk.$k; if($arr){ $lists += "<b>$k</b><ul>"+(($arr|ForEach-Object{"<li>$_</li>"}) -join "")+"</ul>" }
  }
  $lists += "</div>"
}
$listsHtml = "<div class='section'><h2>Shopping Lists (2‑week blocks)</h2><div class='grid'>$lists</div></div>"

$rows = @()
foreach($d in $j.days){
  $ml = @()
  foreach($m in $d.meals){
    $items = ($m.items | ForEach-Object { "$($_.quantity) $($_.unit) $($_.ingredient) $($_.notes)" }) -join "<br>"
    $ml += "<div><b>$($m.name)</b> — for $($m.for)<br><small>$($m.kcal) kcal, Na $($m.sodium_mg) mg, sugar $($m.added_sugars_g) g, fiber $($m.fiber_g) g</small><br>$items</div>"
  }
  $rows += "<tr><td>Day $($d.index) — $($d.day_label)</td><td>$($ml -join '<hr>')</td></tr>"
}
$daysHtml = "<div class='section'><h2>Daily Plan</h2><table><tr><th>Day</th><th>Meals</th></tr>$($rows -join "")</table></div>"

$body = "$head$listsHtml$daysHtml"
Set-Content -Path $html -Value "<!doctype html><meta charset='utf-8'><title>Carol Plan</title>$style<body>$body</body>" -Encoding UTF8

$wk = (Get-Command wkhtmltopdf -ErrorAction SilentlyContinue)
if ($wk) { & $wk.Path "--enable-local-file-access" $html $pdf | Out-Null } else { Write-Warning "wkhtmltopdf not found; committed HTML only." }
Write-Host "Exported -> $html" ; if (Test-Path $pdf) { Write-Host "PDF -> $pdf" }
