param([object]$ApplyFixes=$true,[string]$IndexFile="index.html")
function Bool($x){ if($x -is [bool]){return $x}; $s=(""+$x).ToLower(); return @("1","true","yes","on","t") -contains $s }
$apply = Bool $ApplyFixes
$Root = Split-Path -Parent $PSScriptRoot
$index = Join-Path $Root $IndexFile
$txt = (Get-Content -Raw -Path $index -Encoding UTF8)
$re1 = [regex]::new('location\.(assign|replace)\s*\(\s*["' + "'" + r'"][^"' + "'" + r']+\?v=[^"' + "'" + r']+["' + "'" + r']\s*\)\s*;?', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
$re2 = [regex]::new('searchParams\.has\(\s*["' + "'" + r']v["' + "'" + r']\s*\)', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
$new = $re2.Replace($re1.Replace($txt,"<!-- removed ?v redirect -->"),"false")
if($apply -and $new -ne $txt){ Set-Content -Path $index -Encoding UTF8 -NoNewline -Value $new }
