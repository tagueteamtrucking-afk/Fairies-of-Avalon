param([string]$Root=".")
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSScriptRoot
$repo = Join-Path $here $Root
function Read-Text($p){ try{ return [IO.File]::ReadAllText($p) } catch { return $null } }
function Add-Edge([ref]$edges,[string]$src,[string]$dst){ if([string]::IsNullOrWhiteSpace($src) -or [string]::IsNullOrWhiteSpace($dst)){ return }; $edges.Value += @{ from=$src; to=$dst } }
$edges = @()
$wfDir = Join-Path $repo ".github/workflows"
if(Test-Path $wfDir){
  $wfs = Get-ChildItem -Path $wfDir -File -Recurse -Include *.yml,*.yaml
  foreach($wf in $wfs){
    $txt = Read-Text $wf.FullName; if($null -eq $txt){ continue }
    $src = "/"+($wf.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
    $rx = [regex]"pwsh\s+-File\s+([^\s""']+\.ps1)"
    foreach($m in $rx.Matches($txt)){
      $dst = $m.Groups[1].Value.Replace('\','/'); if(-not $dst.StartsWith("/")){ $dst = "/"+$dst }
      Add-Edge ([ref]$edges) $src $dst
    }
  }
}
$sDir = Join-Path $repo "scripts"
if(Test-Path $sDir){
  $scripts = Get-ChildItem -Path $sDir -File -Recurse -Include *.ps1
  foreach($s in $scripts){
    $txt = Read-Text $s.FullName; if($null -eq $txt){ continue }
    $src = "/"+($s.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
    $rx = [regex]"pwsh\s+-File\s+([^\s""']+\.ps1)"
    foreach($m in $rx.Matches($txt)){
      $dst = $m.Groups[1].Value.Replace('\','/'); if(-not $dst.StartsWith("/")){ $dst = "/"+$dst }
      Add-Edge ([ref]$edges) $src $dst
    }
  }
}
$pages = Get-ChildItem -Path $repo -File -Recurse -Include *.html,*.htm
foreach($p in $pages){
  $txt = Read-Text $p.FullName; if($null -eq $txt){ continue }
  $src = "/"+($p.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
  $rx = [regex]"(?:href|src)\s*=\s*[""']([^""']+)[""']"
  foreach($m in $rx.Matches($txt)){
    $val = $m.Groups[1].Value
    if($val -match '^https?://'){ continue }
    Add-Edge ([ref]$edges) $src $val
  }
}
$jsfiles = Get-ChildItem -Path $repo -File -Recurse -Include *.js,*.mjs,*.ts
foreach($p in $jsfiles){
  $txt = Read-Text $p.FullName; if($null -eq $txt){ continue }
  $src = "/"+($p.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
  foreach($rx in @(
    [regex]"import\s+[^;]*?from\s*[""']([^""']+)[""']",
    [regex]"import\(\s*[""']([^""']+)[""']\s*\)",
    [regex]"fetch\(\s*[""']([^""']+)[""']"
  )){
    foreach($m in $rx.Matches($txt)){
      $val = $m.Groups[1].Value
      if($val -match '^https?://'){ continue }
      Add-Edge ([ref]$edges) $src $val
    }
  }
}
$css = Get-ChildItem -Path $repo -File -Recurse -Include *.css
foreach($p in $css){
  $txt = Read-Text $p.FullName; if($null -eq $txt){ continue }
  $src = "/"+($p.FullName.Replace($repo,"").TrimStart('\','/').Replace('\','/'))
  $rx = [regex]"url\(\s*[""']?([^""'\)]+)[""']?\s*\)"
  foreach($m in $rx.Matches($txt)){
    $val = $m.Groups[1].Value
    if($val -match '^https?://'){ continue }
    Add-Edge ([ref]$edges) $src $val
  }
}
$out = @{ updated = (Get-Date).ToUniversalTime().ToString("s")+"Z"; edges = $edges }
$outPath = Join-Path $here "memory-history/repo-refs.json"
$dir = Split-Path -Parent $outPath; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($outPath, ($out | ConvertTo-Json -Depth 6), [Text.Encoding]::UTF8)
Write-Host "Wrote $outPath with $($edges.Count) edges."
