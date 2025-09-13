# Seed permission requests (optionally auto-grant)
[CmdletBinding()]
param(
  [switch]$GrantAll
)
$ErrorActionPreference = 'Stop'

$Root  = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Queue = Join-Path $Root 'apps\overseers\queue'
$Perms = Join-Path $Root 'apps\overseers\permissions'
New-Item -ItemType Directory -Force -Path $Queue,$Perms | Out-Null

# Ensure profiles file exists
$profilesPath = Join-Path $Perms 'profiles.json'
if (-not (Test-Path $profilesPath)) {
  $default = @'
{
  "schema":"avalon-permissions-1",
  "profiles":{"overseer_full":{"description":"placeholder","scopes":[],"vault_refs":[]}}
}
'@
  Set-Content -LiteralPath $profilesPath -Encoding UTF8 -NoNewline -Value $default
}

# Create tasks: request full Overseer for Rey & White Star
$ts = (Get-Date).ToString('s')+'Z'
$reqs = @(
  @{ id="perm:req:rey";  type="permissions_request"; assignee="rey_czar";   profile="overseer_full"; requested_ts=$ts },
  @{ id="perm:req:star"; type="permissions_request"; assignee="white_star"; profile="overseer_full"; requested_ts=$ts }
)

$i = 1
foreach ($r in $reqs) {
  $file = ("{0:D3}_perm_request_{1}.json" -f $i, $r.assignee)
  ($r | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $Queue $file) -Encoding UTF8 -NoNewline
  $i++
}

if ($GrantAll) {
  foreach ($r in $reqs) {
    $g = @{
      id = "perm:grant:$($r.assignee)"
      type = "permissions_grant"
      assignee = $r.assignee
      profile = $r.profile
      approved_by = "white_star"
      approved_ts = $ts
    }
    $file = ("{0:D3}_perm_grant_{1}.json" -f $i, $r.assignee)
    ($g | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $Queue $file) -Encoding UTF8 -NoNewline
    $i++
  }
}

Write-Host "Seeded permission request task(s). GrantAll=$($GrantAll.IsPresent)"
exit 0
