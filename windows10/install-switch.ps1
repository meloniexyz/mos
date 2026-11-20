#Requires -Version 5.1
<#
.SYNOPSIS
  Run once on the daily Windows 10 after MOS is installed. Adds a "Play VALORANT" desktop shortcut that restarts
  into MOS one time (asks for admin, because changing the next boot needs it). The boot default is not changed.
  Remove: delete the shortcut and %ProgramData%\MOS-switch.
#>
[CmdletBinding()]
param([string]$DesktopPath = [Environment]::GetFolderPath('Desktop'))
$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:ProgramData 'MOS-switch'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'play-valorant.ps1') -Destination $dir -Force

$lnkPath = Join-Path $DesktopPath 'Play VALORANT.lnk'
$sh = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut($lnkPath)
$lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $dir 'play-valorant.ps1'))
$lnk.Description = 'Restart once into MOS'
$lnk.Save()

# set the shortcut's "Run as administrator" flag (byte 0x15, bit 0x20 of the .lnk header)
$bytes = [IO.File]::ReadAllBytes($lnkPath)
$bytes[0x15] = $bytes[0x15] -bor 0x20
[IO.File]::WriteAllBytes($lnkPath, $bytes)

Write-Host "Created $lnkPath" -ForegroundColor Green
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    . (Join-Path $dir 'play-valorant.ps1')
    $r = Find-MosBootEntry (& bcdedit.exe /enum /v) 'MOS'
    Write-Host $r.Message -ForegroundColor $(if ($r.Status -eq 'ok') { 'Green' } else { 'Yellow' })
}
else { Write-Host 'Run this as administrator to also confirm that the MOS boot entry is found.' -ForegroundColor Yellow }
