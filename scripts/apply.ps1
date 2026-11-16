# ASCII only. Apply the Cursor language pack (bundle translation + switching extension).
# Supply-chain safety: the package version is pinned and the tarball is verified
# against a known SHA-512 before any of its code runs.
param(
  [string]$Locale = 'zh-cn',
  [string]$CursorDir = '',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache',
  [string]$Package = '@polang233/cursor-language-pack@1.2.0',
  [string]$ExpectedIntegrity = 'sha512-qTJNW44qwKMmQeqRcWGdVzF6e2CKte6BF1Rxt94jeRi9ZHe/WHsWPSDru6DExcvWrby7iFlIn69kzJkCQrtleg=='
)

$ErrorActionPreference = 'Continue'
$env:ELECTRON_RUN_AS_NODE = $null
[Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

function Fail($msg) { Write-Host ('[FAIL] ' + $msg); exit 1 }
function Step($msg) { Write-Host ('[STEP] ' + $msg) }
function Ok($msg)   { Write-Host ('[OK]   ' + $msg) }

$version = ($Package -split '@')[-1]
if ($version -notmatch '^\d+\.\d+\.\d+$') {
  Fail 'refusing an unpinned package spec; pass an exact version such as @polang233/cursor-language-pack@1.2.0'
}

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

# ---------- 2. close Cursor ----------
Step 'closing Cursor'
Get-Process -Name Cursor -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 8
$alive = @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count
if ($alive -gt 0) { Fail ('Cursor still running (' + $alive + ' processes)') }
Ok 'Cursor closed'

# ---------- 3. fetch and verify package ----------
Step ('fetching ' + $Package)
$stage = Join-Path $CacheDir $version
$marker = Join-Path $stage 'verified-integrity.txt'
$pkgDir = Join-Path $stage 'package'

$verified = (Test-Path (Join-Path $pkgDir 'package.json')) -and
            (Test-Path $marker) -and
            ((Get-Content $marker -Raw).Trim() -eq $ExpectedIntegrity)

if ($verified) {
  Ok 'cached copy already verified'
} else {
  if (-not (Test-Path $stage)) { New-Item -ItemType Directory -Force -Path $stage | Out-Null }
  Push-Location $stage
  # '--' stops npm from parsing the spec as an option
  $packOut = & npm pack -- $Package --pack-destination $stage 2>&1
  Pop-Location
  $tgz = Get-ChildItem $stage -Filter '*.tgz' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $tgz) { Fail ('npm pack failed: ' + ($packOut -join ' ')) }

  $sha = [Security.Cryptography.SHA512]::Create()
  $b64 = [Convert]::ToBase64String($sha.ComputeHash([IO.File]::ReadAllBytes($tgz.FullName)))
  $actual = 'sha512-' + $b64
  if ($actual -ne $ExpectedIntegrity) {
    Fail ('integrity mismatch; refusing to run. expected=' + $ExpectedIntegrity + ' actual=' + $actual)
  }
  Ok 'tarball integrity verified'

  & tar -xzf $tgz.FullName -C $stage 2>&1 | Out-Null
  if (-not (Test-Path (Join-Path $pkgDir 'package.json'))) { Fail 'package extraction failed' }
  [IO.File]::WriteAllText($marker, $ExpectedIntegrity, (New-Object Text.UTF8Encoding($false)))
}

# ---------- 4. version compatibility ----------
Step 'checking version compatibility'
$cfg = Get-Content (Join-Path $pkgDir 'config.json') -Raw | ConvertFrom-Json
$curVer = (Get-Content (Join-Path $CursorDir 'resources\app\product.json') -Raw | ConvertFrom-Json).version
$verifiedList = @($cfg.target.verifiedCursorVersions)
if ($verifiedList -contains $curVer) { Ok ('Cursor ' + $curVer + ' is in verified list') }
else { Write-Host ('[WARN] Cursor ' + $curVer + ' not in verified list: ' + ($verifiedList -join ', ')) }

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
$script = Join-Path $pkgDir 'scripts\translate-install.mjs'
$vsix   = Join-Path $pkgDir 'assets\language-pack.vsix'
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
$packState = Join-Path $env:USERPROFILE '.cursor\cursor-language-pack'
$bk = Get-ChildItem $packState -Recurse -Directory -Filter 'backup' -ErrorAction SilentlyContinue | Select-Object -First 1
$bkCount = 0
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
