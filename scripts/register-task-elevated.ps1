# ASCII only. Runs elevated: registers the auto-watch scheduled task.
# This script writes NO files. An elevated process must not accept an arbitrary
# output path (symlink / reparse-point and TOCTOU risks), so the result is
# printed to the console only. Callers verify success with Get-ScheduledTask,
# which does not require elevation.
param(
  [string]$Locale = 'zh-cn'
)

$ErrorActionPreference = 'Stop'
$taskName = 'Cursor Chinese Auto'
$watch = Join-Path $PSScriptRoot 'auto-watch.ps1'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name

if (-not (Test-Path $watch)) { throw ('auto-watch.ps1 not found: ' + $watch) }

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $watch + '" -Locale ' + $Locale

try {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
  $t1 = New-ScheduledTaskTrigger -AtLogOn
  $t2 = New-ScheduledTaskTrigger -Daily -At '12:00'
  $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force | Out-Null
  Write-Host '[OK] registered scheduled task: Cursor Chinese Auto'
  $info = Get-ScheduledTask -TaskName $taskName
  Write-Host ('     state: ' + $info.State)
  Write-Host ('     next:  ' + (Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime)
  exit 0
} catch {
  Write-Host ('[FAIL] ' + $_.Exception.Message)
  exit 1
}
