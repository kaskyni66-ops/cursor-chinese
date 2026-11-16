# ASCII only. Runs elevated: registers the auto-watch scheduled task.
# The result file is created with CreateNew and is rejected if any path component
# is a reparse point, so an elevated write cannot be redirected by a planted link.
param(
  [Parameter(Mandatory = $true)][string]$ResultFile,
  [string]$Locale = 'zh-cn'
)

$ErrorActionPreference = 'Stop'

function Assert-SafePath([string]$path) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path -LiteralPath $dir)) { throw ('result directory missing: ' + $dir) }
  $di = Get-Item -LiteralPath $dir -Force
  if ($di.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw ('refusing to write: ' + $dir + ' is a reparse point')
  }
  if (Test-Path -LiteralPath $path) { throw ('refusing to write: ' + $path + ' already exists') }
}

Assert-SafePath $ResultFile

$lines = New-Object System.Collections.Generic.List[string]
$watch = Join-Path $PSScriptRoot 'auto-watch.ps1'
$taskName = 'Cursor Chinese Auto'
$me = [Security.Principal.WindowsIdentity]::GetCurrent().Name

$lines.Add('elevated: ' + (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
$lines.Add('user: ' + $me)
$lines.Add('watch: ' + $watch)

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $watch + '" -Locale ' + $Locale

try {
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine
  $t1 = New-ScheduledTaskTrigger -AtLogOn
  $t2 = New-ScheduledTaskTrigger -Daily -At '12:00'
  $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force | Out-Null
  $lines.Add('RESULT: registered')
  $info = Get-ScheduledTask -TaskName $taskName
  $lines.Add('state: ' + $info.State)
  $lines.Add('next: ' + (Get-ScheduledTaskInfo -TaskName $taskName).NextRunTime)
} catch {
  $lines.Add('RESULT: failed - ' + $_.Exception.Message)
}

$text = ($lines -join "`r`n")
try {
  $fs = [IO.File]::Open($ResultFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
  $sw = New-Object IO.StreamWriter($fs, (New-Object Text.UTF8Encoding($false)))
  $sw.Write($text)
  $sw.Flush(); $sw.Close(); $fs.Close()
  Write-Host $text
} catch {
  Write-Host ('[WARN] could not write result file: ' + $_.Exception.Message)
  Write-Host $text
}
