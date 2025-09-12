param(
  [ValidateSet('route','scopes','mempatch','all')]
  [string]$Action = 'all'
)

$ErrorActionPreference = "Stop"

function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Json($path,$obj){ Ensure-Dir (Split-Path $path); $obj | ConvertTo-Json -Depth 32 | Set-Content -Path $path -NoNewline -Encoding UTF8 }
function Write-Text($path,$txt){ Ensure-Dir (Split-Path $path); $txt | Set-Content -Path $path -NoNewline -Encoding UTF8 }

$memPath = "Cody's Memory.yaml"
$mem     = ConvertFrom-Yaml (Get-Content -Raw -LiteralPath $memPath)

$outRoot = "apps/overseers/out"
Ensure-Dir $outRoot

# plan.route
if ($Action -eq 'route' -or $Action -eq 'all') {
  $route = [ordered]@{
    priority_plan = $mem.priority_plan
    tasks         = $mem.plans.overseers_full_roster_queue.tasks
    notes         = "R1: app shell + importer; R2: H·W·W plan; R3: fairy scaffolds. Source: Memory v$($mem.meta.version)"
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Json "$outRoot/route.json" $route
}

# auth.scope_plan (least privilege per Fairy; draft)
if ($Action -eq 'scopes' -or $Action -eq 'all') {
  $scopesDir = Join-Path $outRoot "scopes"
  Ensure-Dir $scopesDir

  foreach ($fairy in $mem.entities.fairies) {
    $s = @()
    switch ($fairy.id) {
      'abbey'   { $s = @('quickbooks.readwrite','gmail.read','files.read','files.write_scoped','budgets.manage','reports.read') }
      'themis'  { $s = @('reminders.write','calendar.readwrite','compliance.readwrite','files.read') }
      'billie'  { $s = @('ecommerce.readwrite','analytics.read','files.read','reports.read') }
      'sorcha'  { $s = @('social.publish','files.read','analytics.read') }
      'carol_li'{ $s = @('files.read','nutrition.recommend','reminders.write') }
      'jem_nassim'{ $s = @('files.read','fitness.plan','reminders.write') }
      default   { $s = @('files.read','files.write_scoped') }
    }
    $obj = [ordered]@{
      id          = $fairy.id
      name        = $fairy.name
      principle   = "least-privilege"
      scopes      = $s
      status      = "draft"
      generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    Write-Json (Join-Path $scopesDir "$($fairy.id).json") $obj
  }
}

# mem.patch (proposal only; we respect whole-file replacement policy)
if ($Action -eq 'mempatch' -or $Action -eq 'all') {
  $proposal = @"
# Memory Patch Proposal — Rey Czar
- Set `plans.overseers_full_roster_queue.status` -> "in_progress".
- Add `runtime.quick_paths.overseers_console` -> "pages/apps/overseers.html".
- Confirm `project.importmap_required` stays true; import map already embedded in /pages.

(Generate a new full file when approved; no inline edits. This note was produced by apps/overseers/ai/rey-czar.ps1)
"@
  Write-Text "$outRoot/mem_patch_proposal.md" $proposal
}

Write-Text "$outRoot/rey-czar.ok" ("Rey Czar ran: " + (Get-Date).ToString("o"))
