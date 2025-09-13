Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-YamlModule {
  try {
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
      Write-Host "Installing powershell-yaml..."
      Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
      Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber -Confirm:$false
    }
    Import-Module powershell-yaml -ErrorAction Stop
    Write-Host "powershell-yaml is ready."
  } catch {
    Write-Error "Failed to install/import powershell-yaml. $_"
    throw
  }
}

function Read-YamlFiles([string]$Glob) {
  $files = Get-ChildItem -Path $Glob -ErrorAction SilentlyContinue
  $items = @()
  foreach ($f in $files) {
    $raw = Get-Content -Path $f.FullName -Raw
    $obj = ConvertFrom-Yaml -Yaml $raw
    $obj.PSObject.Properties.Add((New-Object System.Management.Automation.PSNoteProperty("sourceFile", $f.FullName)))
    $items += $obj
  }
  return $items
}

function Write-Json([object]$Data, [string]$Path) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $json = $Data | ConvertTo-Json -Depth 20
  Set-Content -Path $Path -Value $json -Encoding UTF8
  Write-Host "Wrote $Path"
}
