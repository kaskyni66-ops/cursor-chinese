# ASCII only. Detect Cursor install, version, current language state.
$ErrorActionPreference = 'SilentlyContinue'

function Find-CursorDir {
  $candidates = @(
    'E:\Cursor',
    "$env:LOCALAPPDATA\Programs\cursor",
    'C:\Program Files\Cursor',
    'D:\Cursor'
  )
  foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c 'resources\app\product.json')) { return $c }
  }
  $p = Get-Process -Name Cursor -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p -and $p.Path) { return (Split-Path $p.Path -Parent) }
  return $null
}

$dir = Find-CursorDir
if (-not $dir) { 'cursor_dir=NOT_FOUND'; exit 1 }
'cursor_dir=' + $dir

$product = Join-Path $dir 'resources\app\product.json'
$j = Get-Content $product -Raw | ConvertFrom-Json
'cursor_version=' + $j.version
'vscode_version=' + $j.vscodeVersion

$extDir = Join-Path $env:USERPROFILE '.cursor\extensions'
$hasPack = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'polang233.cursor-language-pack*' }).Count
$hasMs = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'ms-ceintl.*' }).Count
'pack_installed=' + ($hasPack -gt 0)
'official_pack_installed=' + ($hasMs -gt 0)

$argv = Join-Path $env:USERPROFILE '.cursor\argv.json'
if (Test-Path $argv) {
  $t = Get-Content $argv -Raw
  $m = [regex]::Match($t, '"locale"\s*:\s*"([^"]*)"')
  'argv_locale=' + $(if ($m.Success) { $m.Groups[1].Value } else { '(not set)' })
} else { 'argv_locale=(no file)' }

# Backups live under ~/.cursor/cursor-language-pack/installs/<...>/backup
$packState = Join-Path $env:USERPROFILE '.cursor\cursor-language-pack'
$bk = Get-ChildItem $packState -Recurse -Directory -Filter 'backup' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bk) {
  'backup_files=' + @(Get-ChildItem $bk.FullName -File -ErrorAction SilentlyContinue).Count
} else { 'backup_files=0' }

'cursor_running=' + (@(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count -gt 0)
