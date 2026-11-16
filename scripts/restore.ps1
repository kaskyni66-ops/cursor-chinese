# ASCII only. Restore Cursor program files and set display language back to English.
param(
  [string]$CursorDir = '',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache'
)

$ErrorActionPreference = 'Continue'
$env:ELECTRON_RUN_AS_NODE = $null
[Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

function Fail($msg) { Write-Host ('[FAIL] ' + $msg); exit 1 }
function Step($msg) { Write-Host ('[STEP] ' + $msg) }
function Ok($msg)   { Write-Host ('[OK]   ' + $msg) }

Step 'locating Cursor'
if (-not $CursorDir) {
  foreach ($c in @('E:\Cursor', "$env:LOCALAPPDATA\Programs\cursor", 'C:\Program Files\Cursor', 'D:\Cursor')) {
    if (Test-Path (Join-Path $c 'resources\app\product.json')) { $CursorDir = $c; break }
  }
}
if (-not $CursorDir) { Fail 'Cursor install not found; pass -CursorDir' }

Step 'closing Cursor'
Get-Process -Name Cursor -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 8
Ok ('alive: ' + @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count)

$script = Join-Path $CacheDir 'package\scripts\translate-install.mjs'
if (-not (Test-Path $script)) { Fail ('installer not cached at ' + $CacheDir + '; run apply.ps1 once first') }

Step 'restoring program files from backup'
$out = & node $script ('--dir=' + $CursorDir) --undo 2>&1
$out | Select-Object -Last 10 | ForEach-Object { Write-Host ('   ' + $_.ToString()) }

Step 'setting display language to en'
$argv = Join-Path $env:USERPROFILE '.cursor\argv.json'
if (Test-Path $argv) {
  $t = Get-Content $argv -Raw
  if ($t -match '"locale"\s*:\s*"[^"]*"') {
    $t2 = $t -replace '"locale"\s*:\s*"[^"]*"', '"locale": "en"'
  } else {
    $t2 = $t -replace '\{', "{`r`n`t`"locale`": `"en`","
  }
  [IO.File]::WriteAllText($argv, $t2, (New-Object Text.UTF8Encoding($false)))
  Ok 'locale set to en'
} else { Write-Host '[INFO] argv.json not found' }

Step 'starting Cursor'
Start-Process -FilePath (Join-Path $CursorDir 'Cursor.exe') -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
Ok ('Cursor processes: ' + @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count)
