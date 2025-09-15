[CmdletBinding()]
param([string]$RepoRoot=".")
$ErrorActionPreference='Stop'
try { Import-Module powershell-yaml -ErrorAction Stop } catch {
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
  Import-Module powershell-yaml -ErrorAction Stop
}
$src = Join-Path $RepoRoot "pages/apps/themis/records.yaml"
$items = @()
if (Test-Path $src){
  try{ $items = (Get-Content -Raw -Path $src) | ConvertFrom-Yaml } catch { $items=@() }
}
if ($items.Count -eq 0){
  $items = @(
    @{ item='Domain renewal'; due='2026-01-01' },
    @{ item='SSL certificate'; due='2026-02-15' }
  )
}
$now = Get-Date
$rem = @()
foreach($it in $items){
  try{
    $due = Get-Date $it.due
    $days = [math]::Ceiling(($due - $now).TotalDays)
    $rem += [pscustomobject]@{ item=$it.item; due_date=$due.ToString('yyyy-MM-dd'); days_remaining=$days }
  }catch{}
}
$outDir = Join-Path $RepoRoot "pages/apps/themis"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
($rem | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "reminders.json") -Encoding utf8NoBOM
Write-Host "Reminders written."
exit 0
