<#
.SYNOPSIS
    Removes vd-hotkeys: stops the script, deletes autostart and the install folder.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -KeepFiles
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'VDHotkeys'),
    [switch]$KeepFiles
)

$ErrorActionPreference = 'Stop'
$TaskName = 'VDHotkeys'

Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
    Where-Object { $_.CommandLine -like '*vd-hotkeys.ahk*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Scheduled task '$TaskName' removed"
}

$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'vd-hotkeys.lnk'
if (Test-Path $startupLnk) {
    Remove-Item $startupLnk -Force
    Write-Host 'Startup shortcut removed'
}

# delete only a folder that really is a vd-hotkeys install
if (-not $KeepFiles -and (Test-Path (Join-Path $InstallDir 'vd-hotkeys.ahk'))) {
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "Removed $InstallDir"
}
