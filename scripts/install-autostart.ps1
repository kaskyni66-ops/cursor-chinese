# ASCII only. Register (or remove) the scheduled task that keeps Cursor translated.
param(
  [string]$Locale = 'zh-cn',
  [string]$CacheDir = 'D:\Tools\cursor-chinese\cache',
  [switch]$Uninstall
)

$ErrorActionPreference = 'Continue'
$taskName = 'Cursor Chinese Auto'

if ($Uninstall) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  & schtasks.exe /Delete /TN $taskName /F 2>&1 | Out-Null
  Write-Host ('[OK] removed scheduled task: ' + $taskName)
  exit 0
}

$watch = Join-Path $PSScriptRoot 'auto-watch.ps1'
if (-not (Test-Path $watch)) { throw ('auto-watch.ps1 not found: ' + $watch) }

$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host ('[INFO] registering as: ' + $me)

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $watch + '" -Locale ' + $Locale + ' -CacheDir "' + $CacheDir + '"'

$registered = $false
try {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
  $t1 = New-ScheduledTaskTrigger -AtLogOn
  $t2 = New-ScheduledTaskTrigger -Daily -At '12:00'
  $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
  $registered = $true
  Write-Host '[OK] registered via Register-ScheduledTask'
} catch {
  Write-Host ('[WARN] Register-ScheduledTask failed: ' + $_.Exception.Message)
  Write-Host '[INFO] falling back to schtasks.exe'
  $tr = 'powershell.exe ' + $argLine
  $r = & schtasks.exe /Create /TN $taskName /TR $tr /SC ONLOGON /RL LIMITED /F 2>&1
  Write-Host ('   ' + ($r -join ' '))
  $registered = ($LASTEXITCODE -eq 0)
  if ($registered) { Write-Host '[OK] registered via schtasks (logon trigger only)' }
}

if (-not $registered) { Write-Host '[FAIL] could not register the scheduled task'; exit 1 }

$info = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($info) {
  Write-Host ('[OK] ' + $info.TaskName + '  state=' + $info.State)
  Write-Host ('     next run: ' + (Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime)
}
Write-Host ('     locale:   ' + $Locale)
Write-Host ('     log:      ' + (Join-Path $CacheDir 'logs\auto-watch.log'))
