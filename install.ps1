<#
.SYNOPSIS
    Installs vd-hotkeys: hotkeys that move the active window between Windows 11 virtual desktops.

.DESCRIPTION
    Downloads portable AutoHotkey v2 and the VirtualDesktopAccessor.dll build that matches your Windows,
    verifies their SHA-256, copies vd-hotkeys.ahk into the install folder, registers autostart and starts it.

    Run it from an elevated PowerShell: autostart is then a logon task with highest privileges, so the
    hotkeys also work while a window running as administrator is active. Without elevation a Startup
    folder shortcut is used instead.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    irm https://raw.githubusercontent.com/Er2003/vd-hotkeys/main/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'VDHotkeys')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # the progress bar makes Invoke-WebRequest very slow in Windows PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$RepoRaw  = 'https://raw.githubusercontent.com/Er2003/vd-hotkeys/main'
$TaskName = 'VDHotkeys'

# Pinned downloads with known SHA-256
$Ahk = @{
    Url    = 'https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.30/AutoHotkey_2.0.30.zip'
    Sha256 = '1e0ece7ecb2d5646e55758150472677996a57f9db5c83d2996d8b47b9e2f31a4'
}
$VdaBuilds = @{
    '23H2' = @{
        Tag    = '2024-01-25-windows11'
        Url    = 'https://github.com/Ciantic/VirtualDesktopAccessor/releases/download/2024-01-25-windows11/VirtualDesktopAccessor.dll'
        Sha256 = 'f78ff6334f6c0ef5175ec0819026cec31d421a564b9ed1ee1ac4b6ed98d4f999'
    }
    '24H2' = @{
        Tag    = '2024-12-16-windows11'
        Url    = 'https://github.com/Ciantic/VirtualDesktopAccessor/releases/download/2024-12-16-windows11/VirtualDesktopAccessor.dll'
        Sha256 = '8740c572a1c000e3b87ffeb1e4c397eae9af3bd4a2abdc3bcffacab4493f8ff5'
    }
}

function Get-Verified([string]$Url, [string]$Sha256, [string]$OutFile) {
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    $actual = (Get-FileHash $OutFile -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $Sha256) {
        Remove-Item $OutFile -Force
        throw "SHA-256 mismatch for $Url`n  expected $Sha256`n  actual   $actual"
    }
}

# 1. VirtualDesktopAccessor build for this Windows
$cv    = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build = [int]$cv.CurrentBuild
$ubr   = [int]$cv.UBR
if ($build -ge 26100) {
    if ($build -eq 26100 -and $ubr -lt 2605) {
        throw "Windows 11 24H2 build 26100.$ubr is older than 26100.2605 required by VirtualDesktopAccessor. Install Windows updates first."
    }
    $vda = $VdaBuilds['24H2']
} elseif ($build -eq 22631 -or ($build -eq 22621 -and $ubr -ge 2215)) {
    $vda = $VdaBuilds['23H2']
} else {
    throw "Windows build $build.$ubr is not supported. Supported: Windows 11 22H2 (22621.2215+), 23H2 (22631) and 24H2+ (26100.2605+)."
}
Write-Host "Windows build $build.$ubr -> VirtualDesktopAccessor $($vda.Tag)"

# 2. Stop a running copy so its files can be replaced
Get-CimInstance Win32_Process -Filter "Name='AutoHotkey64.exe'" |
    Where-Object { $_.CommandLine -like '*vd-hotkeys.ahk*' } |
    ForEach-Object {
        $procId = $_.ProcessId
        try { Stop-Process -Id $procId -Force }
        catch { throw "Cannot stop running vd-hotkeys (PID $procId); it was probably started as administrator. Re-run install.ps1 from an elevated PowerShell." }
    }

# 3. Files
$exe    = Join-Path $InstallDir 'ahk\AutoHotkey64.exe'
$script = Join-Path $InstallDir 'vd-hotkeys.ahk'
New-Item -ItemType Directory -Force (Join-Path $InstallDir 'ahk'), (Join-Path $InstallDir 'lib') | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('vd-hotkeys-' + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
try {
    Get-Verified $Ahk.Url $Ahk.Sha256 (Join-Path $tmp 'ahk.zip')
    Expand-Archive (Join-Path $tmp 'ahk.zip') -DestinationPath (Join-Path $tmp 'ahk')
    Copy-Item (Join-Path $tmp 'ahk\AutoHotkey64.exe'), (Join-Path $tmp 'ahk\license.txt') (Join-Path $InstallDir 'ahk') -Force

    Get-Verified $vda.Url $vda.Sha256 (Join-Path $tmp 'VirtualDesktopAccessor.dll')
    Copy-Item (Join-Path $tmp 'VirtualDesktopAccessor.dll') (Join-Path $InstallDir 'lib') -Force

    # the script lies next to install.ps1, or comes from GitHub when run via irm | iex
    $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'vd-hotkeys.ahk' }
    if ($local -and (Test-Path $local)) {
        Copy-Item $local $script -Force
    } else {
        Invoke-WebRequest -Uri "$RepoRaw/vd-hotkeys.ahk" -OutFile $script -UseBasicParsing
    }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Autostart and start
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'vd-hotkeys.lnk'
if ($isAdmin) {
    $user      = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action    = New-ScheduledTaskAction -Execute $exe -Argument "`"$script`"" -WorkingDirectory $InstallDir
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
        -Description 'vd-hotkeys: Win+Ctrl+Shift+Left/Right/1-9 moves the active window, Ctrl+Shift+Alt+Win+Left/Right/1-9 goes to a virtual desktop' -Force | Out-Null
    if (Test-Path $startupLnk) { Remove-Item $startupLnk -Force }
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Autostart: scheduled task '$TaskName' (at logon, highest privileges)"
} else {
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($startupLnk)
    $lnk.TargetPath       = $exe
    $lnk.Arguments        = "`"$script`""
    $lnk.WorkingDirectory = $InstallDir
    $lnk.Save()
    Start-Process $exe -ArgumentList "`"$script`"" -WorkingDirectory $InstallDir
    Write-Warning ("Not elevated: autostart is a Startup folder shortcut, and the hotkeys will not reach windows " +
        "running as administrator. Re-run install.ps1 from an elevated PowerShell to fix that.")
}

Write-Host "Installed to $InstallDir"
Write-Host 'Move window:   Win+Ctrl+Shift + Left/Right/1..9'
Write-Host 'Go to desktop: Ctrl+Shift+Alt+Win + Left/Right/1..9'
