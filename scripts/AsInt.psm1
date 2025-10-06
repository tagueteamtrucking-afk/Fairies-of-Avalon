# Requires -Version 5.1
# Robust numeric coercion. Always declare parameters as [object] and coerce via As-Int.
# Avoids the common Object[]→Int32 pitfalls when receiving numbers/arrays from Actions inputs.

function As-Int {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,
    [switch]$AllowNull
  )

  if ($null -eq $Value) {
    if ($AllowNull) { return $null }
    throw "As-Int: Value is null and AllowNull is not set."
  }

  # If already integer-like
  if ($Value -is [int]) { return [int]$Value }
  if ($Value -is [long]) { return [int][long]$Value }

  # If it's a real number, round
  if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
    return [int][Math]::Round([double]$Value, 0)
  }

  # Strings and other scalar types
  $s = [string]$Value
  if ([string]::IsNullOrWhiteSpace($s)) {
    if ($AllowNull) { return $null }
    throw "As-Int: Empty string is not a valid integer."
  }
  $s = $s.Trim()

  # Hex literal
  if ($s -match '^\s*0x[0-9A-Fa-f]+\s*$') {
    return [int][Convert]::ToInt64($s, 16)
  }

  # Remove grouping separators/underscores/spaces
  $s2 = ($s -replace '[,_\s]', '')

  # Booleans
  if ($s2 -ieq 'true') { return 1 }
  if ($s2 -ieq 'false') { return 0 }

  # Decimal? Round
  if ($s2 -match '^-?\d+\.\d+$') {
    return [int][Math]::Round([double]$s2, 0)
  }

  # Integer
  if ($s2 -match '^-?\d+$') {
    return [int]$s2
  }

  # Arrays / enumerables — coerce each element
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $out = @()
    foreach ($item in $Value) {
      $out += (As-Int -Value $item -AllowNull:$AllowNull.IsPresent)
    }
    # Return the first element if only one, else array length (sensible default)
    if ($out.Count -eq 1) { return [int]$out[0] }
    return [int]$out.Count
  }

  throw "As-Int: Cannot coerce '$Value' to integer."
}

Export-ModuleMember -Function As-Int
