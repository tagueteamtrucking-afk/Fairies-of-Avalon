[CmdletBinding()]
param(
  [string]$RepoRoot=".",
  [string]$SeedPath="",
  [int]$Regions=5,
  [string]$TaxonomyPath="pages/apps/alexandria/knowledge/atlas-taxonomy.json",
  [switch]$ForceFallback
)
$ErrorActionPreference='Stop'
function Iso(){ (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Slug([string]$s){ if([string]::IsNullOrWhiteSpace($s)){return "world"}; return ($s -replace '[^A-Za-z0-9]+','-').Trim('-').ToLower().Substring(0,[Math]::Min(80,$s.Length)) }

$root = (Resolve-Path $RepoRoot).Path
$worldsDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds"
if (-not (Test-Path $worldsDir)) { throw "No seeds directory found: $worldsDir" }

# Seed
$seedFile = $null
if ($SeedPath) {
  $candidate = Join-Path $RepoRoot $SeedPath
  if (-not (Test-Path $candidate)) { throw "Seed file not found: $SeedPath" }
  $seedFile = Get-Item $candidate
} else {
  $files = Get-ChildItem $worldsDir -Filter *.json | Sort-Object LastWriteTime -Descending
  if ($files.Count -eq 0) { throw "No seed files found under /pages/apps/alexandria/worlds. Generate one first." }
  $seedFile = $files | Select-Object -First 1
}
try{ $seed = Get-Content -Raw -Path $seedFile.FullName | ConvertFrom-Json -Depth 100 }catch{ throw "Invalid seed JSON: $($seedFile.FullName)" }

# Taxonomy (atlas) + bible-derived for culture/gov/currency
$tax = $null
$taxFull = Join-Path $RepoRoot $TaxonomyPath
if (Test-Path $taxFull) { try{ $tax = Get-Content -Raw -Path $taxFull | ConvertFrom-Json -Depth 100 }catch{ $tax=$null } }

$bibleTax = $null
$biblePath = Join-Path $RepoRoot "pages/apps/alexandria/knowledge/bible-taxonomy.json"
if (Test-Path $biblePath) { try{ $bibleTax = Get-Content -Raw -Path $biblePath | ConvertFrom-Json -Depth 100 }catch{ $bibleTax=$null } }

function Pick([object[]]$arr){ if(-not $arr -or $arr.Count -eq 0){ return $null } return $arr[(Get-Random -Minimum 0 -Maximum $arr.Count)] }

$cnt = [Math]::Max(1,[Math]::Min(32, $Regions))
$f1 = if($seed.factions.Count -ge 1){ $seed.factions[0].name } else { 'Faction A' }
$f2 = if($seed.factions.Count -ge 2){ $seed.factions[1].name } else { 'Faction B' }

$reg = @()
for($i=0;$i -lt $cnt;$i++){
  $r = [pscustomobject]@{
    id = $i
    name = "Region " + ($i+1)
    dimension = (Pick $tax.dimension_types)
    biome = (Pick $tax.biomes)
    climate = (Pick $tax.climates)
    faction = (Pick @($f1,$f2,'Independent','Unclaimed'))
    hazard = (Pick $tax.hazards)
    resource = (Pick $tax.resources)
    culture = (Pick $bibleTax.cultures)
    government = (Pick $bibleTax.governments)
    currency = (Pick $bibleTax.currencies)
    wing_friendly = ((Get-Random) % 5 -ne 0)
    poi = @()
  }
  $reg += $r
}

# Portals & leys (same as before)
$portals = @()
$ley = @()
if ($reg.Count -ge 2){
  $pn = [Math]::Min($reg.Count-1, (Get-Random -Minimum 1 -Maximum ([Math]::Min(5,$reg.Count))))
  for($i=0;$i -lt $pn;$i++){
    $a = Get-Random -Minimum 0 -Maximum $reg.Count
    $b = Get-Random -Minimum 0 -Maximum $reg.Count
    if ($a -ne $b) { $portals += [pscustomobject]@{ from=$a; to=$b; type=(Pick $tax.gate_types) } }
  }
  $ln = [Math]::Min($reg.Count-1, (Get-Random -Minimum 1 -Maximum ([Math]::Min(6,$reg.Count))))
  $aff = @('mana','storm','shadow','sun','tide')
  for($i=0;$i -lt $ln;$i++){
    $a = Get-Random -Minimum 0 -Maximum $reg.Count
    $b = Get-Random -Minimum 0 -Maximum $reg.Count
    if ($a -ne $b) { $ley += [pscustomobject]@{ from=$a; to=$b; affinity=(Pick $aff) } }
  }
}

# Optional region lore omitted (unchanged from previous pack to keep this minimal)

# Dimensions summary
$dimensions = @()
foreach($d in ($reg | ForEach-Object { $_.dimension } | Select-Object -Unique)){
  if ($null -ne $d) {
    $dimensions += [pscustomobject]@{
      id = $dimensions.Count
      name = $d
      timeflow = (Pick $tax.timeflow)
      magic = (Pick $tax.magic_intensity)
      tech = (Pick $tax.tech_levels)
    }
  }
}

$atlas = [pscustomobject]@{
  id = "atlas-" + (Get-Date -Format 'yyyyMMddHHmmss')
  seed_id = $seed.id
  title = $seed.title
  generated = (Iso)
  format_version = "1.0.0"
  dimensions = $dimensions
  regions = $reg
  portals = $portals
  leylines = $ley
}

$outDir = Join-Path $RepoRoot "pages/apps/alexandria/worlds/atlas"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$slug = Slug $seed.title
$name = "$slug.atlas.json"
$rel  = "/apps/alexandria/worlds/atlas/$name"
($atlas | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir $name) -Encoding utf8NoBOM
($atlas | ConvertTo-Json -Depth 100) | Set-Content -Path (Join-Path $outDir "latest.json") -Encoding utf8NoBOM

# Index
$indexPath = Join-Path $outDir "index.json"
$index = @()
if (Test-Path $indexPath){ try { $index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json -Depth 100 } catch { $index=@() } }
$index = @($index | Where-Object { $_.path -ne $rel })
$index += [pscustomobject]@{ path=$rel; title=$seed.title; id=$atlas.id; regions=$reg.Count; dims=$dimensions.Count; ts=(Iso) }
($index | ConvertTo-Json -Depth 100) | Set-Content -Path $indexPath -Encoding utf8NoBOM
Write-Host "Atlas written: $rel"
exit 0
