$root=Split-Path -Parent $PSScriptRoot
$in = Join-Path $root 'pages/apps/theme/tokens.json'
$outCss = Join-Path $root 'pages/apps/theme/tokens.css'
$outJs  = Join-Path $root 'pages/apps/theme/tokens.js'
if(-not (Test-Path $in)){
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $in) | Out-Null
  $default = @{
    color = @{
      bg = "#0b0f17"; ink = "#e5e7eb"; card = "#0f172a"; line = "#172033"; accent = "#60a5fa"
    }
    radius = @{ md = "10px"; lg = "12px" }
    space  = @{ sm = "6px"; md = "10px"; lg = "14px" }
    font   = @{ base = "system-ui, Segoe UI, Roboto, Helvetica, Arial, sans-serif" }
  }
  [IO.File]::WriteAllText($in, ($default | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
}
$j = Get-Content -Raw -Path $in | ConvertFrom-Json
$css=":root{"
$j.color.PSObject.Properties | ForEach-Object { $name=$_.Name; $val=$_.Value; $css += "--color-"+$name+":"+ $val + ";"; }
$j.radius.PSObject.Properties | ForEach-Object { $name=$_.Name; $val=$_.Value; $css += "--radius-"+$name+":"+ $val + ";"; }
$j.space.PSObject.Properties  | ForEach-Object { $name=$_.Name; $val=$_.Value; $css += "--space-"+$name+":"+ $val + ";"; }
$css += "}\nbody{background:var(--color-bg);color:var(--color-ink);font-family:"+$j.font.base+"}"
[IO.File]::WriteAllText($outCss, $css, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($outJs, "export default "+(Get-Content -Raw -Path $in), [Text.Encoding]::UTF8)
Write-Host "Tokens -> $outCss, $outJs"
