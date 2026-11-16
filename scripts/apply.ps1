# ASCII only. Apply the Cursor language pack (bundle translation + switching extension).
param(
  [string]$Locale = 'zh-cn',
  [string]$CursorDir = '',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache',
  [string]$Package = '@polang233/cursor-language-pack@latest'
)

$ErrorActionPreference = 'Continue'
$env:ELECTRON_RUN_AS_NODE = $null
[Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

function Fail($msg) { Write-Host ('[FAIL] ' + $msg); exit 1 }
function Step($msg) { Write-Host ('[STEP] ' + $msg) }
function Ok($msg)   { Write-Host ('[OK]   ' + $msg) }

# ---------- 1. locate Cursor ----------
Step 'locating Cursor'
if (-not $CursorDir) {
  foreach ($c in @('E:\Cursor', "$env:LOCALAPPDATA\Programs\cursor", 'C:\Program Files\Cursor', 'D:\Cursor')) {
    if (Test-Path (Join-Path $c 'resources\app\product.json')) { $CursorDir = $c; break }
  }
}
if (-not $CursorDir -or -not (Test-Path (Join-Path $CursorDir 'resources\app\product.json'))) {
  Fail 'Cursor install not found; pass -CursorDir'
}
Ok ('Cursor at ' + $CursorDir)

# ---------- 2. font: quit Cursor ----------
Step 'closing Cursor'
Get-Process -Name Cursor -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 8
$alive = @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count
if ($alive -gt 0) { Fail ('Cursor still running (' + $alive + ' processes)') }
Ok 'Cursor closed'

# ---------- 3. fetch package ----------
Step 'fetching language pack'
if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }
$pkgJson = Join-Path $CacheDir 'package\package.json'
if (-not (Test-Path $pkgJson)) {
  Push-Location $CacheDir
  $packOut = & npm pack $Package --pack-destination $CacheDir 2>&1
  $tgz = Get-ChildItem $CacheDir -Filter '*.tgz' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $tgz) { Pop-Location; Fail ('npm pack failed: ' + ($packOut -join ' ')) }
  $extract = Join-Path $CacheDir 'package'
  if (-not (Test-Path $extract)) { New-Item -ItemType Directory -Force -Path $extract | Out-Null }
  & tar -xzf $tgz.FullName -C $CacheDir 2>&1 | Out-Null
  Pop-Location
}
if (-not (Test-Path $pkgJson)) { Fail 'package extraction failed' }
$ver = (Get-Content $pkgJson -Raw | ConvertFrom-Json).version
Ok ('language pack ' + $ver)

# ---------- 4. version compatibility ----------
Step 'checking version compatibility'
$cfg = Get-Content (Join-Path $CacheDir 'package\config.json') -Raw | ConvertFrom-Json
$curVer = (Get-Content (Join-Path $CursorDir 'resources\app\product.json') -Raw | ConvertFrom-Json).version
$verified = @($cfg.target.verifiedCursorVersions)
if ($verified -contains $curVer) { Ok ('Cursor ' + $curVer + ' is in verified list') }
else { Write-Host ('[WARN] Cursor ' + $curVer + ' not in verified list: ' + ($verified -join ', ')) }

# ---------- 5. remove conflicting official pack ----------
Step 'removing conflicting official language pack'
$cli = Join-Path $CursorDir 'resources\app\bin\cursor.cmd'
if (Test-Path $cli) {
  $r = & $cli --uninstall-extension 'ms-ceintl.vscode-language-pack-zh-hans' 2>&1
  $txt = ($r | ForEach-Object { $_.ToString() }) -join ' '
  if ($txt -match 'successfully uninstalled') { Ok 'official pack removed' }
  else { Write-Host '[INFO] official pack not installed (fine)' }
} else { Write-Host '[INFO] Cursor CLI not found; skip' }

# ---------- 6. run the installer with explicit vsix ----------
Step 'applying translations'
$script = Join-Path $CacheDir 'package\scripts\translate-install.mjs'
$vsix   = Join-Path $CacheDir 'package\assets\language-pack.vsix'
if (-not (Test-Path $script)) { Fail 'translate-install.mjs missing' }
if (-not (Test-Path $vsix))   { Fail 'language-pack.vsix missing' }

$out = & node $script ('--dir=' + $CursorDir) ('--locale=' + $Locale) ('--vsix=' + $vsix) 2>&1
$code = $LASTEXITCODE
$out | Select-Object -Last 12 | ForEach-Object { Write-Host ('   ' + $_.ToString()) }

# ---------- 7. verify by evidence, not by exit code ----------
Step 'verifying'
$extDir = Join-Path $env:USERPROFILE '.cursor\extensions'
$packOk = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'polang233.cursor-language-pack*' }).Count -gt 0
$argv = Join-Path $env:USERPROFILE '.cursor\argv.json'
$locOk = $false
if (Test-Path $argv) {
  $m = [regex]::Match((Get-Content $argv -Raw), '"locale"\s*:\s*"([^"]*)"')
  $locOk = ($m.Success -and $m.Groups[1].Value -eq $Locale)
}
$bkCount = 0
$bk = Get-ChildItem (Join-Path $env:APPDATA 'Cursor') -Recurse -Directory -Filter 'backup' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bk) { $bkCount = @(Get-ChildItem $bk.FullName -File -ErrorAction SilentlyContinue).Count }

Write-Host ('   extension_installed=' + $packOk)
Write-Host ('   locale_set=' + $locOk)
Write-Host ('   backup_files=' + $bkCount)

if ($packOk -and $locOk -and $bkCount -ge 3) { Ok 'translation applied' }
else { Fail ('verification failed (installer exit=' + $code + ')') }

# ---------- 8. relaunch ----------
Step 'starting Cursor'
Start-Process -FilePath (Join-Path $CursorDir 'Cursor.exe') -ErrorAction SilentlyContinue
Start-Sleep -Seconds 20
Ok ('Cursor processes: ' + @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count)
Write-Host ''
Write-Host 'Done. If the UI is still English, run restore.ps1 then apply.ps1 again.'
