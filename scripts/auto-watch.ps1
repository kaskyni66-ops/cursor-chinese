# ASCII only. Detect a Cursor upgrade and re-apply the language pack automatically.
# Designed to run unattended from a scheduled task (logon / daily).
param(
  [string]$Locale = 'zh-cn',
  [string]$CursorDir = '',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache',
  [switch]$Force
)

$ErrorActionPreference = 'Continue'
$env:ELECTRON_RUN_AS_NODE = $null
[Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

$logDir = Join-Path $CacheDir 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$logFile = Join-Path $logDir 'auto-watch.log'
function Log($m) {
  $line = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $m
  [IO.File]::AppendAllText($logFile, $line + "`r`n", (New-Object Text.UTF8Encoding($false)))
  Write-Host $line
}

# ---------- locate Cursor ----------
if (-not $CursorDir) {
  foreach ($c in @('E:\Cursor', "$env:LOCALAPPDATA\Programs\cursor", 'C:\Program Files\Cursor', 'D:\Cursor')) {
    if (Test-Path (Join-Path $c 'resources\app\product.json')) { $CursorDir = $c; break }
  }
}
if (-not $CursorDir) { Log 'Cursor not found; nothing to do'; exit 0 }

$version = (Get-Content (Join-Path $CursorDir 'resources\app\product.json') -Raw | ConvertFrom-Json).version
Log ('Cursor version: ' + $version)

# ---------- current translation state ----------
$extDir  = Join-Path $env:USERPROFILE '.cursor\extensions'
$argv    = Join-Path $env:USERPROFILE '.cursor\argv.json'
$packOk  = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'polang233.cursor-language-pack*' }).Count -gt 0

$locale = ''
if (Test-Path $argv) {
  $m = [regex]::Match((Get-Content $argv -Raw), '"locale"\s*:\s*"([^"]*)"')
  if ($m.Success) { $locale = $m.Groups[1].Value }
}

$packState = Join-Path $env:USERPROFILE '.cursor\cursor-language-pack'
$bk = Get-ChildItem $packState -Recurse -Directory -Filter 'backup' -ErrorAction SilentlyContinue | Select-Object -First 1
$bkCount = 0
if ($bk) { $bkCount = @(Get-ChildItem $bk.FullName -File -ErrorAction SilentlyContinue).Count }

Log ('state: extension=' + $packOk + ' locale=' + $(if ($locale) { $locale } else { '(none)' }) + ' backup_files=' + $bkCount)

# ---------- state record ----------
$stateFile = Join-Path $CacheDir 'state.json'
$state = $null
if (Test-Path $stateFile) { try { $state = Get-Content $stateFile -Raw | ConvertFrom-Json } catch { } }

$healthy = $packOk -and ($locale -eq $Locale) -and ($bkCount -ge 3)
$sameVersion = $state -and ($state.version -eq $version)

if ($healthy -and $sameVersion -and -not $Force) {
  Log 'up to date; nothing to do'
  exit 0
}

# ---------- do not disturb a running session ----------
$running = @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count
if ($running -gt 0) {
  Log ('Cursor is running (' + $running + ' processes); deferring. Close Cursor and the next run will finish it.')
  exit 0
}

# ---------- re-apply ----------
$apply = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\apply.ps1'
if (-not (Test-Path $apply)) { $apply = Join-Path $PSScriptRoot 'apply.ps1' }
Log ('applying language pack: ' + $apply)
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -Locale $Locale -CursorDir $CursorDir -CacheDir $CacheDir -NoRelaunch 2>&1
$code = $LASTEXITCODE
$out | Select-Object -Last 8 | ForEach-Object { Log ('   ' + $_.ToString()) }

if ($code -eq 0) {
  $st = [ordered]@{ version = $version; locale = $Locale; appliedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
  [IO.File]::WriteAllText($stateFile, ($st | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
  Log 'applied successfully'
} else {
  Log ('apply failed with exit code ' + $code)
}
exit $code
