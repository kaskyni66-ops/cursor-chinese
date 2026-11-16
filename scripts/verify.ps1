# ASCII only. Verify the Cursor language pack state by evidence.
param([string]$Locale = 'zh-cn')

$ErrorActionPreference = 'SilentlyContinue'
$ok = $true

$extDir = Join-Path $env:USERPROFILE '.cursor\extensions'
$pack = @(Get-ChildItem $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'polang233.cursor-language-pack*' })
if ($pack.Count -gt 0) { Write-Host ('[OK]   extension: ' + $pack[0].Name) }
else { Write-Host '[FAIL] extension polang233.cursor-language-pack not installed'; $ok = $false }

$argv = Join-Path $env:USERPROFILE '.cursor\argv.json'
$loc = ''
if (Test-Path $argv) {
  $m = [regex]::Match((Get-Content $argv -Raw), '"locale"\s*:\s*"([^"]*)"')
  if ($m.Success) { $loc = $m.Groups[1].Value }
}
if ($loc -eq $Locale) { Write-Host ('[OK]   argv locale = ' + $loc) }
else { Write-Host ('[FAIL] argv locale = ' + $(if ($loc) { $loc } else { '(unset)' }) + ' (expected ' + $Locale + ')'); $ok = $false }

# Backups created by the pack live under ~/.cursor/cursor-language-pack/installs/<...>/backup
$packState = Join-Path $env:USERPROFILE '.cursor\cursor-language-pack'
$bk = Get-ChildItem $packState -Recurse -Directory -Filter 'backup' -ErrorAction SilentlyContinue | Select-Object -First 1
$bkCount = 0
if ($bk) { $bkCount = @(Get-ChildItem $bk.FullName -File -ErrorAction SilentlyContinue).Count }
if ($bkCount -ge 3) { Write-Host ('[OK]   backup files = ' + $bkCount) }
else { Write-Host ('[WARN] backup files = ' + $bkCount + ' (translation may not be applied)'); $ok = $false }

$proc = @(Get-Process -Name Cursor -ErrorAction SilentlyContinue).Count
Write-Host ('[INFO] Cursor processes = ' + $proc)

if ($ok) { Write-Host ''; Write-Host 'PASS - open Cursor and confirm the menus/settings show Chinese.'; exit 0 }
else { Write-Host ''; Write-Host 'FAIL - run apply.ps1'; exit 1 }
