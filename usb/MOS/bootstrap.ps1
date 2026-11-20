#Requires -Version 5.1
<#
.SYNOPSIS
  MOS first-logon setup, started by autounattend.xml from the install USB.
  1. finds the USB (MOS\mos.usb marker)  2. copies MOS\ to C:\MOS  3. marks this Windows as MOS
  4. keeps the daily Windows 10 as boot default, names this entry "MOS"  5. permanent auto-logon
  6. desktop shortcuts  7. tune.ps1 apply (standard profile)
  Safe to run again by hand: it stops if it already finished.
#>
[CmdletBinding()]
param(
    [string[]]$DriveRoots,
    [string]$Destination = (Join-Path $env:SystemDrive 'MOS'),
    [string]$DesktopPath = [Environment]::GetFolderPath('Desktop'),
    [switch]$NoTune
)
$ErrorActionPreference = 'Stop'

function Find-MosUsb([string[]]$Roots) {
    if (-not $Roots) { $Roots = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }) }
    foreach ($r in $Roots) {
        if ($r.TrimEnd('\') -ieq $env:SystemDrive) { continue }
        if (Test-Path -LiteralPath (Join-Path $r 'MOS\mos.usb')) { return $r }
    }
    $null
}

function Write-DesktopNote([string]$Name, [string]$Text) {
    if (-not (Test-Path -LiteralPath $DesktopPath)) { New-Item -ItemType Directory -Path $DesktopPath -Force | Out-Null }
    $p = Join-Path $DesktopPath $Name
    Set-Content -LiteralPath $p -Value $Text -Encoding UTF8
    $p
}

function New-Shortcut([string]$Path, [string]$TargetPath, [string]$Arguments, [string]$Description) {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($Path)
    $lnk.TargetPath = $TargetPath
    $lnk.Arguments = $Arguments
    $lnk.Description = $Description
    $lnk.Save()
}

# "MOS check" shortcut: tuning drift first, then the doctor's health report. Both read-only.
function Get-MosCheckArguments([string]$Root) {
    '-NoExit -ExecutionPolicy Bypass -Command "& ''{0}'' check; & ''{1}''"' -f (Join-Path $Root 'tune\tune.ps1'), (Join-Path $Root 'doctor.ps1')
}

function Test-Elevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$script:ManualHelp = @"
To finish MOS setup by hand:
  1. Plug the MOS install USB back in.
  2. Right-click Start > Terminal (Admin), then run:
       powershell -ExecutionPolicy Bypass -File <USB>:\MOS\bootstrap.ps1
"@

function Invoke-MosBootstrap {
    $done = Join-Path $Destination '.bootstrap-done'
    if (Test-Path -LiteralPath $done) { Write-Host 'MOS bootstrap already finished.'; return 'already-done' }

    $usb = Find-MosUsb $DriveRoots
    if (-not $usb) {
        $note = Write-DesktopNote 'MOS setup NOT finished.txt' ("The MOS install USB was not found, so MOS was not set up or tuned.`r`n`r`n" + $script:ManualHelp)
        Write-Warning "MOS USB not found. Wrote $note"
        return 'no-usb'
    }

    if (-not (Test-Elevated)) {
        # FirstLogonCommands normally run elevated; if not, ask once through UAC.
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f (Join-Path $usb 'MOS\bootstrap.ps1')) -ErrorAction Stop
            return 'relaunched-elevated'
        }
        catch {
            $note = Write-DesktopNote 'MOS setup NOT finished.txt' ("MOS setup needs administrator rights and the prompt was declined.`r`n`r`n" + $script:ManualHelp)
            Write-Warning "Not elevated. Wrote $note"
            return 'not-elevated'
        }
    }

    New-Item -ItemType Directory -Path (Join-Path $Destination 'logs') -Force | Out-Null
    $log = Join-Path $Destination 'logs\bootstrap.log'
    function Log([string]$m) { Add-Content -LiteralPath $log -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) -Encoding UTF8; Write-Host $m }
    $warnings = New-Object System.Collections.ArrayList

    Log "USB found at $usb"
    & robocopy.exe (Join-Path $usb 'MOS') $Destination /E /XF mos.usb /XD results state logs /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copying MOS files failed (robocopy $LASTEXITCODE)." }
    Log "Files copied to $Destination"

    Set-Content -LiteralPath (Join-Path $Destination '.mos-host') -Value "MOS host marker. Created $(Get-Date -Format o)." -Encoding ASCII
    New-Item -Path 'HKLM:\SOFTWARE\MOS' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\MOS' -Name Host -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\MOS' -Name InstalledAt -Value (Get-Date -Format o) -PropertyType String -Force | Out-Null
    Log 'Host marker written'

    # boot menu: daily Windows 10 stays default, this entry is called "MOS"
    $guidFile = Join-Path $usb 'MOS\boot\main.guid'
    $mainGuid = if (Test-Path -LiteralPath $guidFile) { (Get-Content -LiteralPath $guidFile -TotalCount 1).Trim() } else { $null }
    if ($mainGuid -match '^\{[0-9a-fA-F-]{36}\}$') {
        $all = (& bcdedit.exe /enum all /v) -join "`n"
        if ($all -match [regex]::Escape($mainGuid)) {
            & bcdedit.exe /default $mainGuid | Out-Null
            Log "Boot default set back to Windows 10 entry $mainGuid"
        }
        else { [void]$warnings.Add("Windows 10 boot entry $mainGuid not in this boot menu; default left as is (see INSTALL.md, 'two EFI partitions')."); Log $warnings[-1] }
    }
    else { [void]$warnings.Add('No Windows 10 boot entry recorded (prep-usb.ps1 not run?); boot default left as is.'); Log $warnings[-1] }
    & bcdedit.exe /set '{current}' description 'MOS' | Out-Null
    Log 'This boot entry renamed to MOS'

    # permanent auto-logon (the answer file's AutoLogon has a logon count)
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $wl -Name AutoAdminLogon -Value '1'
    Set-ItemProperty -Path $wl -Name DefaultUserName -Value $env:USERNAME
    Set-ItemProperty -Path $wl -Name DefaultPassword -Value ''
    Remove-ItemProperty -Path $wl -Name AutoLogonCount -ErrorAction SilentlyContinue
    Log 'Auto-logon made permanent'

    New-Shortcut (Join-Path $DesktopPath 'Back to Windows.lnk') "$env:SystemRoot\System32\shutdown.exe" '/r /t 0' 'Restart into the daily Windows 10 (the boot default)'
    New-Shortcut (Join-Path $DesktopPath 'MOS check.lnk') "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" (Get-MosCheckArguments $Destination) 'Read-only: tuning drift + doctor (RAM profile, refresh rate, background load...)'
    Log 'Desktop shortcuts created'

    if (-not $NoTune) {
        Log 'Running tune.ps1 apply (standard profile)'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Destination 'tune\tune.ps1') apply 2>&1 | ForEach-Object { Add-Content -LiteralPath $log -Value "    $_" -Encoding UTF8 }
        Log "tune.ps1 finished with exit code $LASTEXITCODE (1 is expected on first boot: Vanguard is not installed yet)"
    }

    Set-Content -LiteralPath $done -Value (Get-Date -Format o) -Encoding ASCII
    $next = @"
MOS is set up. Next steps (also in docs\INSTALL.md):
  1. Restart once (Hyper-V/VBS removal and GPU interrupt mode take effect after a reboot).
  2. Install the NVIDIA driver: Custom > Graphics Driver only > Clean installation.
  3. Run as admin: powershell -ExecutionPolicy Bypass -File C:\MOS\seed-valorant.ps1
  4. Install the Riot Client, point it at C:\Riot Games\VALORANT, let it verify, restart for Vanguard.
  5. Launch VALORANT once, close it, then run as admin: C:\MOS\tune\tune.ps1 apply
"@
    if ($warnings.Count) { $next += "`r`nWarnings:`r`n  - " + ($warnings -join "`r`n  - ") }
    $null = Write-DesktopNote 'MOS next steps.txt' $next
    Log 'Bootstrap finished'
    'done'
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-MosBootstrap }
