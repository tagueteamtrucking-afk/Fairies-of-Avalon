[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
$outDir = Join-Path $RepoRoot "pages/apps/abbey"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$incomeFile = Join-Path $outDir "income.json"
$expFile    = Join-Path $outDir "expenses.json"
$income = 0.0
$expenses = 0.0
$break = @{}
if (Test-Path $incomeFile){ try{ $j = Get-Content -Raw -Path $incomeFile | ConvertFrom-Json; $income = [double]$j.total }catch{} }
if (Test-Path $expFile){
  try{ $j = Get-Content -Raw -Path $expFile | ConvertFrom-Json;
       foreach($k in $j.PSObject.Properties.Name){ $v=[double]$j.$k; $break[$k]=$v; $expenses += $v } }catch{}
}
$out = @{ income=[double]$income; expenses=[double]$expenses; breakdown=$break; generated=(Get-Date).ToUniversalTime().ToString("s")+'Z' }
($out | ConvertTo-Json -Depth 30) | Set-Content -Path (Join-Path $outDir "budget.json") -Encoding utf8NoBOM
Write-Host "Budget written."
exit 0
