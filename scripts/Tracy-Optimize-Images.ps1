$root=Split-Path -Parent $PSScriptRoot
$src=Join-Path $root 'asset/textures/wallpapers'
$dst=Join-Path $root 'asset/textures/wallpapers_optimized'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Write-Host "Installing tools (ImageMagick + webp)"
sudo apt-get update -y
sudo apt-get install -y imagemagick webp || Write-Warning "Install failed; attempting to continue"
Get-ChildItem -Path $src -File -Include *.jpg,*.jpeg,*.png | ForEach-Object {
  $name = $_.BaseName
  $outJpg = Join-Path $dst ($name + "-lg.jpg")
  $outWebp = Join-Path $dst ($name + "-lg.webp")
  magick $_.FullName -strip -auto-orient -resize 2560x -quality 82 $outJpg
  cwebp -quiet -q 82 $outJpg -o $outWebp
}
Write-Host "Optimized images -> $dst"
