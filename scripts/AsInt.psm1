# Requires -Version 5.1
function As-Int {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][object]$Value,[switch]$AllowNull)

  if ($null -eq $Value) { if ($AllowNull){return $null} throw "As-Int: Value is null" }
  if ($Value -is [int]) { return [int]$Value }
  if ($Value -is [long]) { return [int][long]$Value }

  if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
    return [int][Math]::Round([double]$Value, 0)
  }

  $s = [string]$Value
  if ([string]::IsNullOrWhiteSpace($s)) { if ($AllowNull){return $null} throw "As-Int: Empty string" }
  $s = $s.Trim()

  if ($s -match '^\s*0x[0-9A-Fa-f]+\s*$') { return [int][Convert]::ToInt64($s,16) }

  $s2 = ($s -replace '[,_\s]', '')

  if ($s2 -ieq 'true')  { return 1 }
  if ($s2 -ieq 'false') { return 0 }

  if ($s2 -match '^-?\d+\.\d+$') { return [int][Math]::Round([double]$s2,0) }
  if ($s2 -match '^-?\d+$')      { return [int]$s2 }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $out=@()
    foreach($i in $Value){ $out += (As-Int -Value $i -AllowNull:$AllowNull.IsPresent) }
    if ($out.Count -eq 1){ return [int]$out[0] }
    return [int]$out.Count
  }

  throw "As-Int: Cannot coerce '$Value'"
}
Export-ModuleMember -Function As-Int
