[CmdletBinding()]
param([string]$RepoRoot=".", [string]$Topic="creative tech", [switch]$ForceFallback)
$ErrorActionPreference='Stop'
$list = @()
if (-not $ForceFallback -and $env:OPENAI_API_KEY){
  $prompt = @"
List 8 grant or scholarship opportunities in the topic: $Topic.
Fields: title, summary (1-2 lines), url (homepage).
Return ONLY valid JSON array.
"@
  $bridge = Join-Path (Join-Path $RepoRoot "scripts/overseers") "llm-bridge.ps1"
  $tmp = Join-Path $env:RUNNER_TEMP "odessa.grants.json"
  try{ & $bridge -Prompt $prompt -OutFile $tmp -DryRun:$false; $list = Get-Content -Raw -Path $tmp | ConvertFrom-Json } catch { $list=@() }
}
if ($list.Count -eq 0){
  $list = @(
    @{ title='Creative Tech Microgrant'; summary='Support for small creative technology projects.'; url='https://example.com/grants/creative-tech' },
    @{ title='Community Arts Fund'; summary='Funding for local arts initiatives.'; url='https://example.com/grants/community-arts' }
  )
}
$outDir = Join-Path $RepoRoot "pages/apps/odessa"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
($list | ConvertTo-Json -Depth 20) | Set-Content -Path (Join-Path $outDir "grants.json") -Encoding utf8NoBOM
Write-Host "Grants list written."
exit 0
