#Requires -Version 5.1
<#
.SYNOPSIS
  MOS doctor: read-only report of things that silently cost fps. Changes nothing.
  RAM profile (XMP/DOCP) lost, display below max refresh, GPU link narrowed, power plan, MSI mode,
  Game Mode, pending restart, free space, driver age, and programs using CPU right now.
.PARAMETER PassThru  Return result objects (and print nothing unless -Quiet:$false is not given).
.PARAMETER Quiet     Don't print the report.
#>
[CmdletBinding()]
param([switch]$PassThru, [switch]$Quiet)

$script:MosPlanGuid = '4d4f5300-0000-4000-8000-000000000001'

# ---------------------------------------------------------------- readers (one fact each; tests replace them)

function Get-DocRam {
    @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ PartNumber = ([string]$_.PartNumber).Trim(); Speed = [int]$_.Speed; Configured = [int]$_.ConfiguredClockSpeed }
        })
}

function Get-DocDisplay {
    try {
        if (-not ('MosDoc.Disp' -as [type])) {
            Add-Type -Namespace MosDoc -Name Disp -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE { [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName; public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput; public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName; public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency, dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
'@
        }
        $dm = New-Object MosDoc.Disp+DEVMODE
        $dm.dmSize = [Runtime.InteropServices.Marshal]::SizeOf($dm)
        if ([MosDoc.Disp]::EnumDisplaySettings($null, -1, [ref]$dm) -and $dm.dmDisplayFrequency -gt 1) {
            $w = $dm.dmPelsWidth; $h = $dm.dmPelsHeight; $cur = $dm.dmDisplayFrequency; $max = $cur; $i = 0
            while ([MosDoc.Disp]::EnumDisplaySettings($null, $i, [ref]$dm)) { if ($dm.dmPelsWidth -eq $w -and $dm.dmPelsHeight -eq $h -and $dm.dmDisplayFrequency -gt $max) { $max = $dm.dmDisplayFrequency }; $i++ }
            return [pscustomobject]@{ Current = $cur; Max = $max; Source = "display settings, ${w}x${h}" }
        }
    }
    catch { }
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.CurrentRefreshRate -gt 1 } | Select-Object -First 1
    if ($vc) { return [pscustomobject]@{ Current = [int]$vc.CurrentRefreshRate; Max = [int]$vc.MaxRefreshRate; Source = 'WMI' } }
    $null
}

function Get-DocGpuLink {
    $smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if (-not (Test-Path -LiteralPath $smi)) { return $null }
    $out = & $smi --query-gpu=pcie.link.width.current,pcie.link.width.max --format=csv,noheader,nounits 2>$null | Select-Object -First 1
    if ("$out" -match '^\s*(\d+)\s*,\s*(\d+)') { return [pscustomobject]@{ Width = [int]$Matches[1]; MaxWidth = [int]$Matches[2] } }
    $null
}

function Get-DocPowerPlan {
    $out = powercfg /getactivescheme 2>$null
    if ("$out" -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s*\(([^)]*)\)') {
        return [pscustomobject]@{ Guid = $Matches[1].ToLower(); Name = $Matches[2] }
    }
    $null
}

function Get-DocMsi {
    $gpu = Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like 'PCI\VEN_10DE*' } | Select-Object -First 1
    if (-not $gpu) { return $null }
    # Dependent/Antecedent are CIM references: use their key properties (their string form is truncated)
    $id = $gpu.InstanceId
    $irq = Get-CimInstance Win32_PnPAllocatedResource -ErrorAction SilentlyContinue |
        Where-Object { $_.Antecedent.CimClass.CimClassName -eq 'Win32_IRQResource' -and [string]::Equals([string]$_.Dependent.DeviceID, $id, [StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1
    if (-not $irq) { return $null }
    [pscustomobject]@{ Irq = [int64]$irq.Antecedent.IRQNumber }
}

function Get-DocGameMode {
    $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled
    [pscustomobject]@{ Enabled = ($null -eq $v -or [int]$v -ne 0) }   # absent = Windows default (on)
}

function Get-DocPendingReboot {
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
}

function Get-DocFreeSpace {
    $d = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($d) { [math]::Round($d.Free / 1GB, 1) } else { $null }
}

function Get-DocDriverAge {
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*NVIDIA*' } | Select-Object -First 1
    if (-not $vc -or -not $vc.DriverDate) { return $null }
    [pscustomobject]@{ Version = $vc.DriverVersion; Date = $vc.DriverDate; Days = [int]((Get-Date) - $vc.DriverDate).TotalDays }
}

$script:DocSystemProcesses = @('idle', '_total', 'system', 'interrupts', 'dwm', 'csrss', 'audiodg', 'msmpeng', 'svchost', 'explorer',
    'registry', 'memory compression', 'lsass', 'services', 'wininit', 'winlogon', 'smss', 'fontdrvhost', 'sihost', 'ctfmon', 'powershell', 'conhost')

function Get-DocBackgroundCpu {
    $s = Get-Counter '\Process(*)\% Processor Time' -SampleInterval 2 -MaxSamples 3 -ErrorAction SilentlyContinue
    if (-not $s) { return $null }
    $agg = @{}
    foreach ($set in $s) { foreach ($c in $set.CounterSamples) {
            $n = ($c.InstanceName -replace '#\d+$', '').ToLower()
            if ($script:DocSystemProcesses -contains $n) { continue }
            if (-not $agg.ContainsKey($n)) { $agg[$n] = 0.0 }
            $agg[$n] += $c.CookedValue
        } }
    @($agg.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Name = $_.Key; PctCore = [math]::Round($_.Value / $s.Count, 1) } } | Sort-Object PctCore -Descending)
}

# ---------------------------------------------------------------- rules

function New-DocResult([string]$Item, [string]$Status, [string]$Detail, [string]$Hint = '') {
    [pscustomobject]@{ Item = $Item; Status = $Status; Detail = $Detail; Hint = $Hint }
}

function Get-RatedFromPartNumber([string]$PartNumber) {
    foreach ($m in [regex]::Matches([string]$PartNumber, '(?<!\d)(\d{4})(?!\d)')) {
        $v = [int]$m.Groups[1].Value
        if ($v -ge 1600 -and $v -le 9600) { return $v }
    }
    $null
}

function Test-DocRam($Ram) {
    $mods = @($Ram)
    if (-not $mods.Count) { return New-DocResult 'RAM speed' 'UNKNOWN' 'no memory modules reported' }
    $worst = $null
    foreach ($m in $mods) {
        $fromPart = Get-RatedFromPartNumber $m.PartNumber
        $rated = @($m.Speed, $fromPart, $m.Configured | Where-Object { $_ }) | Measure-Object -Maximum | Select-Object -Expand Maximum
        $gap = $rated - $m.Configured
        if (-not $worst -or $gap -gt $worst.Gap) { $worst = [pscustomobject]@{ Gap = $gap; Rated = $rated; Configured = $m.Configured; Source = $(if ($fromPart -and $fromPart -ge $m.Speed) { "part number $($m.PartNumber)" } else { 'module' }) } }
    }
    if ($worst.Gap -gt 50) {
        return New-DocResult 'RAM speed' 'WARN' ("running at {0} MT/s, rated {1} MT/s ({2})" -f $worst.Configured, $worst.Rated, $worst.Source) 'Turn the memory profile back on in the BIOS (XMP / DOCP / EXPO). BIOS defaults and some setting changes turn it off.'
    }
    New-DocResult 'RAM speed' 'PASS' ("{0} MT/s, at rated speed" -f $worst.Configured)
}

function Test-DocDisplay($Display) {
    if (-not $Display -or -not $Display.Current) { return New-DocResult 'Refresh rate' 'UNKNOWN' 'could not read the display mode' 'Run the doctor from the desktop.' }
    if ($Display.Max -and $Display.Current -lt ($Display.Max - 2)) {
        return New-DocResult 'Refresh rate' 'WARN' ("{0} Hz, but {1} Hz is available ({2})" -f $Display.Current, $Display.Max, $Display.Source) 'Settings > Display > Advanced display > Choose a refresh rate: pick the highest.'
    }
    New-DocResult 'Refresh rate' 'PASS' ("{0} Hz ({1})" -f $Display.Current, $Display.Source)
}

function Test-DocGpuLink($Link) {
    if (-not $Link) { return New-DocResult 'GPU link width' 'INFO' 'not readable (no NVIDIA driver tools)' }
    if ($Link.Width -lt $Link.MaxWidth) { return New-DocResult 'GPU link width' 'WARN' ("x{0} of x{1}" -f $Link.Width, $Link.MaxWidth) 'Seat the GPU in the top full-length slot; check risers and the slot''s lane sharing in the board manual.' }
    New-DocResult 'GPU link width' 'PASS' ("x{0}" -f $Link.Width)
}

function Test-DocPowerPlan($Plan) {
    if (-not $Plan) { return New-DocResult 'Power plan' 'UNKNOWN' 'could not read the active plan' }
    if ($Plan.Guid -eq $script:MosPlanGuid) { return New-DocResult 'Power plan' 'PASS' 'MOS plan active' }
    New-DocResult 'Power plan' 'WARN' ("active: {0}" -f $Plan.Name) 'Run C:\MOS\tune\tune.ps1 apply -Module power (as admin).'
}

function Test-DocMsi($Msi) {
    if (-not $Msi) { return New-DocResult 'GPU MSI mode' 'UNKNOWN' 'no NVIDIA GPU interrupt found' }
    if ($Msi.Irq -lt 0 -or $Msi.Irq -ge 2147483648) { return New-DocResult 'GPU MSI mode' 'PASS' 'message-signaled interrupts' }
    New-DocResult 'GPU MSI mode' 'WARN' ("line-based IRQ {0}" -f $Msi.Irq) 'Run tune.ps1 apply -Module gpu, then restart (also needed after a driver reinstall).'
}

function Test-DocGameMode($GameMode) {
    if ($GameMode -and $GameMode.Enabled) { return New-DocResult 'Game Mode' 'PASS' 'on' }
    New-DocResult 'Game Mode' 'WARN' 'off' 'Settings > Gaming > Game Mode: On (or tune.ps1 apply -Module game).'
}

function Test-DocPendingReboot($Pending) {
    if ($Pending) { return New-DocResult 'Pending restart' 'WARN' 'Windows is waiting for a restart' 'Restart: some tweaks and updates are not active until then.' }
    New-DocResult 'Pending restart' 'PASS' 'none'
}

function Test-DocFreeSpace($FreeGb) {
    if ($null -eq $FreeGb) { return New-DocResult 'Free space' 'UNKNOWN' 'could not read the system drive' }
    if ($FreeGb -lt 30) { return New-DocResult 'Free space' 'WARN' ("{0} GB free on {1}" -f $FreeGb, $env:SystemDrive) 'Keep 30 GB or more free: VALORANT patches and shader caches need room.' }
    New-DocResult 'Free space' 'PASS' ("{0} GB free" -f $FreeGb)
}

function Test-DocDriverAge($Driver) {
    if (-not $Driver) { return New-DocResult 'GPU driver' 'INFO' 'no NVIDIA driver found' }
    $d = "{0}, {1:yyyy-MM-dd} ({2} days old)" -f $Driver.Version, $Driver.Date, $Driver.Days
    if ($Driver.Days -gt 180) { return New-DocResult 'GPU driver' 'WARN' $d 'Install the current GeForce driver: Custom > Graphics Driver only > Clean installation.' }
    New-DocResult 'GPU driver' 'INFO' $d
}

function Test-DocBackground($Procs) {
    if ($null -eq $Procs) { return New-DocResult 'Background CPU' 'UNKNOWN' 'could not sample processes' }
    $busy = @($Procs | Where-Object { $_.PctCore -gt 2 })
    if ($busy.Count) { return New-DocResult 'Background CPU' 'WARN' (($busy | Select-Object -First 5 | ForEach-Object { "{0} {1}%" -f $_.Name, $_.PctCore }) -join ', ') 'Close these before playing; they compete with the game thread.' }
    New-DocResult 'Background CPU' 'PASS' 'nothing above 2% of a core'
}

# ---------------------------------------------------------------- runner

$script:DocChecks = [ordered]@{
    Ram = @('Get-DocRam', 'Test-DocRam'); Display = @('Get-DocDisplay', 'Test-DocDisplay'); GpuLink = @('Get-DocGpuLink', 'Test-DocGpuLink')
    PowerPlan = @('Get-DocPowerPlan', 'Test-DocPowerPlan'); Msi = @('Get-DocMsi', 'Test-DocMsi'); GameMode = @('Get-DocGameMode', 'Test-DocGameMode')
    PendingReboot = @('Get-DocPendingReboot', 'Test-DocPendingReboot'); FreeSpace = @('Get-DocFreeSpace', 'Test-DocFreeSpace')
    DriverAge = @('Get-DocDriverAge', 'Test-DocDriverAge'); Background = @('Get-DocBackgroundCpu', 'Test-DocBackground')
}

function Invoke-MosDoctor {
    param([hashtable]$Readings = @{})
    foreach ($k in $script:DocChecks.Keys) {
        $reader, $rule = $script:DocChecks[$k]
        try {
            $value = if ($Readings.ContainsKey($k)) { $Readings[$k] } else { & $reader }
            & $rule $value
        }
        catch { New-DocResult $k 'UNKNOWN' $_.Exception.Message }
    }
}

function Show-MosDoctor($Results) {
    Write-Host ''
    Write-Host 'MOS doctor (read-only)' -ForegroundColor White
    foreach ($r in $Results) {
        $c = switch ($r.Status) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'DarkYellow' } }
        Write-Host ("  {0,-8} {1,-16} {2}" -f $r.Status, $r.Item, $r.Detail) -ForegroundColor $c
        if ($r.Status -eq 'WARN' -and $r.Hint) { Write-Host ("           -> {0}" -f $r.Hint) -ForegroundColor DarkGray }
    }
    Write-Host ''
}

if ($MyInvocation.InvocationName -ne '.') {
    $results = @(Invoke-MosDoctor)
    if (-not $Quiet -and -not $PassThru) { Show-MosDoctor $results }
    if ($PassThru) { return $results }
}
