# ASCII only. Apply the Cursor language pack (bundle translation + switching extension).
# Safety properties:
#   - the package version is pinned and the tarball is hashed on every run
#   - code is executed only from a tree extracted during this run
#   - Cursor is closed ONLY after the package has been verified, so a network or
#     integrity failure never interrupts a running session
#   - every modified file is backed up by the upstream installer and can be
#     restored with restore.ps1
param(
  [string]$Locale = 'zh-cn',
  [string]$CursorDir = '',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache',
  [string]$Package = '@polang233/cursor-language-pack@1.2.0',
  [string]$ExpectedIntegrity = 'sha512-qTJNW44qwKMmQeqRcWGdVzF6e2CKte6BF1Rxt94jeRi9ZHe/WHsWPSDru6DExcvWrby7iFlIn69kzJkCQrtleg==',
  [switch]$NoRelaunch,
  [switch]$VerifyOnly
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

# ---------- 1. locate Cursor (read-only) ----------
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
$curVer = (Get-Content (Join-Path $CursorDir 'resources\app\product.json') -Raw | ConvertFrom-Json).version
Ok ('Cursor version ' + $curVer)

# ---------- 2. fetch, verify, extract fresh (read-only to Cursor) ----------
Step ('fetching ' + $Package)
$stage = Join-Path $CacheDir $version
if (-not (Test-Path $stage)) { New-Item -ItemType Directory -Force -Path $stage | Out-Null }

# Prefer the copy vendored in this repository: no network access at all.
$vendorTgz = Join-Path (Split-Path $PSScriptRoot -Parent) 'vendor\polang233-cursor-language-pack-1.2.0.tgz'
if (Test-Path $vendorTgz) {
  $tgz = Get-Item $vendorTgz
  Ok ('using vendored package: ' + $tgz.Name)
} else {
  $tgz = Get-ChildItem $stage -Filter '*.tgz' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $tgz) {
    Push-Location $stage
    # options must come BEFORE '--'; everything after it is a package spec
    $packOut = & npm pack --pack-destination $stage -- $Package 2>&1
    Pop-Location
    $tgz = Get-ChildItem $stage -Filter '*.tgz' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $tgz) { Fail ('npm pack failed: ' + (($packOut | ForEach-Object { $_.ToString() }) -join ' ')) }
  }
}

$hashAlg = [Security.Cryptography.SHA512]::Create()
$actual = 'sha512-' + [Convert]::ToBase64String($hashAlg.ComputeHash([IO.File]::ReadAllBytes($tgz.FullName)))
if ($actual -ne $ExpectedIntegrity) {
  Fail ('integrity mismatch; refusing to run. expected=' + $ExpectedIntegrity + ' actual=' + $actual)
}
Ok ('tarball integrity verified: ' + $tgz.Name)

$runDir = Join-Path $stage ('run-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

# Extract with npm rather than tar: the tar shipped with Git/MSYS mis-parses
# Windows paths ("Cannot connect to D:"). npm installs from the already-verified
# local tarball and runs no scripts.
$installOut = & npm install --prefix $runDir --no-save --ignore-scripts --no-audit --no-fund $tgz.FullName 2>&1
if ($LASTEXITCODE -ne 0) {
  Fail ('extraction failed (npm exit=' + $LASTEXITCODE + '): ' + (($installOut | ForEach-Object { $_.ToString() }) -join ' '))
}
$pkgDir = $null
$nm = Join-Path $runDir 'node_modules'
if (Test-Path $nm) {
  $found = Get-ChildItem $nm -Recurse -Directory -Filter 'cursor-language-pack' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $pkgDir = $found.FullName }
}
if (-not $pkgDir -or -not (Test-Path (Join-Path $pkgDir 'package.json'))) { Fail 'package extraction failed' }
Ok ('extracted into a fresh directory for this run: ' + $pkgDir)

# ---------- 3. version compatibility (read-only) ----------
Step 'checking version compatibility'
$cfgText = Get-Content (Join-Path $pkgDir 'config.json') -Raw
$verifiedList = @()
try {
  $cfg = $cfgText | ConvertFrom-Json
  $verifiedList = @($cfg.target.verifiedCursorVersions)
} catch {
  # config.json is JSONC (contains comments); fall back to a narrow regex read
  $m = [regex]::Match($cfgText, '"verifiedCursorVersions"\s*:\s*\[([^\]]*)\]')
  if ($m.Success) {
    $verifiedList = @([regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  }
}
if ($verifiedList -contains $curVer) { Ok ('Cursor ' + $curVer + ' is in verified list') }
else { Write-Host ('[WARN] Cursor ' + $curVer + ' not in verified list: ' + ($verifiedList -join ', ')) }

if ($VerifyOnly) {
  Ok ('verify-only complete; package at ' + $pkgDir)
  Write-Host '[INFO] Cursor was not touched.'
  exit 0
}

# ---------- 4. close Cursor (only now that everything is verified) ----------
Step 'closing Cursor'
Get-Process -Name Cursor -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 8
$alive = @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count
if ($alive -gt 0) { Fail ('Cursor still running (' + $alive + ' processes)') }
Ok 'Cursor closed'

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
else { Fail ('verification failed (installer exit=' + $code + '). Run restore.ps1 to roll back.') }

# ---------- 8. relaunch ----------
if ($NoRelaunch) {
  Ok 'NoRelaunch set; Cursor not started'
} else {
  Step 'starting Cursor'
  Start-Process -FilePath (Join-Path $CursorDir 'Cursor.exe') -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 20
  Ok ('Cursor processes: ' + @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count)
}
Write-Host ''
Write-Host 'Done. Roll back any time with restore.ps1.'
