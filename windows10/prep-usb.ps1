#Requires -Version 5.1
<#
.SYNOPSIS
  Run on the daily Windows 10, as administrator, after making the Windows 11 USB stick with the Media Creation Tool.
  Copies autounattend.xml and the MOS folder onto the stick, and records this Windows 10's boot entry so MOS can
  keep it as the boot menu default. The answer file gets this Windows' time zone and keyboard layouts filled in.

.EXAMPLE
  .\prep-usb.ps1                 # finds the setup stick automatically
  .\prep-usb.ps1 -Target E:\     # or name it
#>
[CmdletBinding()]
param(
    [string]$Target,
    [string]$MainGuid,          # override the recorded boot entry (tests)
    [switch]$SkipMediaCheck,    # allow a folder that is not Windows setup media (tests)
    [string]$TimeZone,          # default: this Windows' time zone
    [string]$InputLocale        # default: this user's keyboard layouts, e.g. 0409:00000409
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

function Get-CurrentInputLocale {
    # HKCU\Keyboard Layout\Preload lists layout ids (KLID); substitutes map to the real KLID.
    $pre = Get-ItemProperty 'HKCU:\Keyboard Layout\Preload' -ErrorAction SilentlyContinue
    $sub = Get-ItemProperty 'HKCU:\Keyboard Layout\Substitutes' -ErrorAction SilentlyContinue
    $out = foreach ($p in @($pre.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' } | Sort-Object { [int]$_.Name })) {
        $id = [string]$p.Value
        $klid = if ($sub -and $sub.PSObject.Properties[$id]) { [string]$sub.$id } else { $id }
        if ($id -match '^[0-9a-fA-F]{8}$' -and $klid -match '^[0-9a-fA-F]{8}$') { '{0}:{1}' -f $id.Substring(4).ToLower(), $klid.ToLower() }
    }
    if ($out) { ($out | Select-Object -Unique) -join ';' } else { '0409:00000409' }
}

function New-AnswerFileText([string]$Template, [string]$Tz, [string]$Locale) {
    if ($Tz -notmatch '^[A-Za-z0-9 ()+.\-]+$') { throw "Unexpected time zone id '$Tz'." }
    if ($Locale -notmatch '^[0-9a-f]{4}:[0-9a-f]{8}(;[0-9a-f]{4}:[0-9a-f]{8})*$') { throw "Unexpected input locale '$Locale'." }
    $Template.Replace('__TIMEZONE__', $Tz).Replace('__INPUTLOCALE__', $Locale)
}

function Get-BcdCurrentIdentifier([string[]]$BcdText) {
    # parses `bcdedit /enum {current} /v` output: "identifier  {xxxxxxxx-...}"
    foreach ($line in $BcdText) {
        if ($line -match '^\s*identifier\s+(\{[0-9a-fA-F-]{36}\})') { return $Matches[1].ToLower() }
    }
    $null
}

function Test-SetupMedia([string]$Root) {
    (Test-Path (Join-Path $Root 'setup.exe')) -and ((Test-Path (Join-Path $Root 'sources\install.wim')) -or (Test-Path (Join-Path $Root 'sources\install.esd')))
}

function Find-SetupStick {
    $found = @(Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Removable' } |
        ForEach-Object { "$($_.DriveLetter):\" } | Where-Object { Test-SetupMedia $_ })
    if ($found.Count -eq 1) { return $found[0] }
    if (-not $found.Count) { throw 'No Windows setup USB stick found. Make one with the Media Creation Tool first, or pass -Target.' }
    throw "Several setup sticks found ($($found -join ', ')). Pass -Target."
}

function Invoke-PrepUsb {
    if (-not $Target) { $Target = Find-SetupStick }
    $Target = $Target.TrimEnd('\') + '\'
    if (-not (Test-Path -LiteralPath $Target)) { throw "Target $Target does not exist." }
    if ($Target.TrimEnd('\') -ieq $env:SystemDrive) { throw 'Refusing to write to the system drive.' }
    if (-not $SkipMediaCheck -and -not (Test-SetupMedia $Target)) { throw "$Target is not Windows setup media (no setup.exe / sources\install.*)." }

    if (-not $MainGuid) {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) { throw 'Run as administrator (needed to read this Windows'' boot entry).' }
        $MainGuid = Get-BcdCurrentIdentifier (& bcdedit.exe /enum '{current}' /v)
        if (-not $MainGuid) { throw 'Could not read this Windows'' boot entry identifier from bcdedit.' }
    }

    if (-not $TimeZone) { $TimeZone = (Get-TimeZone).Id }
    if (-not $InputLocale) { $InputLocale = Get-CurrentInputLocale }
    $answer = New-AnswerFileText ([IO.File]::ReadAllText((Join-Path $repo 'usb\autounattend.xml'))) $TimeZone $InputLocale
    [IO.File]::WriteAllText((Join-Path $Target 'autounattend.xml'), $answer, (New-Object Text.UTF8Encoding $false))
    $dest = Join-Path $Target 'MOS'
    & robocopy.exe (Join-Path $repo 'usb\MOS') $dest /E /XD results state logs /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copying the MOS folder failed (robocopy $LASTEXITCODE)." }
    New-Item -ItemType Directory -Path (Join-Path $dest 'boot') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dest 'boot\main.guid') -Value $MainGuid -Encoding ASCII

    $presentMon = @(Get-ChildItem (Join-Path $dest 'bench\tools') -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue)
    Write-Host "USB ready: $Target" -ForegroundColor Green
    Write-Host "  autounattend.xml (time zone $TimeZone, keyboard $InputLocale), MOS\ copied; boot entry $MainGuid recorded."
    if (-not $presentMon.Count) { Write-Host '  Note: no PresentMon*.exe in MOS\bench\tools. Benchmarking needs it (see INSTALL.md).' -ForegroundColor Yellow }
    [pscustomobject]@{ Target = $Target; MainGuid = $MainGuid }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-PrepUsb }
