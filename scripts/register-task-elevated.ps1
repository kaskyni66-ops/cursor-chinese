# ASCII only. Runs elevated: registers the auto-watch scheduled task.
param([string]$Locale = 'zh-cn')
$ErrorActionPreference = 'Continue'

$resultFile = 'D:\Tools\cursor-chinese\cache\register-result.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $resultFile) | Out-Null
$l = New-Object System.Collections.Generic.List[string]

$watch = Join-Path $PSScriptRoot 'auto-watch.ps1'
$taskName = 'Cursor Chinese Auto'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$l.Add('elevated: ' + (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
$l.Add('user: ' + $me)
$l.Add('watch: ' + $watch)

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $watch + '" -Locale ' + $Locale

try {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
  $t1 = New-ScheduledTaskTrigger -AtLogOn
  $t2 = New-ScheduledTaskTrigger -Daily -At '12:00'
  $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
  $l.Add('RESULT: registered')
  $info = Get-ScheduledTask -TaskName $taskName
  $l.Add('state: ' + $info.State)
  $l.Add('next: ' + (Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime)
} catch {
  $l.Add('RESULT: failed - ' + $_.Exception.Message)
}

Set-Content -LiteralPath $resultFile -Value $l -Encoding UTF8
'written: ' + $resultFile
