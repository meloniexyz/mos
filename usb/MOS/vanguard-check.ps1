#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only report: does this Windows still meet what Riot Vanguard needs? Changes nothing.
  Some items (TPM) need an elevated shell to read; they show UNKNOWN otherwise.
.PARAMETER PassThru  Return the result objects (used by tune.ps1).
.PARAMETER Quiet     Don't print the table.
#>
[CmdletBinding()]
param([switch]$PassThru, [switch]$Quiet)

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$Item, [string]$Status, [string]$Detail, [string]$Hint = '') {
    [void]$results.Add([pscustomobject]@{ Item = $Item; Status = $Status; Detail = $Detail; Hint = $Hint })
}

$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$startOptions = [string](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -ErrorAction SilentlyContinue).SystemStartOptions
$tokens = @($startOptions -split '\s+' | Where-Object { $_ })
$deviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
$vbsRunning = $deviceGuard -and $deviceGuard.VirtualizationBasedSecurityStatus -eq 2

# 1. Windows 11
$build = [int]$cv.CurrentBuildNumber
$display = if ($cv.PSObject.Properties['DisplayVersion']) { $cv.DisplayVersion } else { $cv.ReleaseId }
if ($build -ge 22000) { Add-Result 'Windows 11' 'PASS' "Windows 11 $display (build $build)" }
else { Add-Result 'Windows 11' 'FAIL' "Windows 10 $display (build $build)" 'MOS is meant to be Windows 11.' }

# 2. Secure Boot
$sb = $null
try { $sb = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $sb = ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -ErrorAction SilentlyContinue).UEFISecureBootEnabled -eq 1) }
if ($sb) { Add-Result 'Secure Boot' 'PASS' 'on' } else { Add-Result 'Secure Boot' 'FAIL' 'off' 'Turn Secure Boot on in the BIOS (Boot > Secure Boot > OS Type: Windows UEFI mode).' }

# 3. TPM 2.0
try {
    $tpm = Get-Tpm -ErrorAction Stop
    $spec = (Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
    $is20 = "$spec" -match '^2\.0'
    if ($tpm.TpmPresent -and $tpm.TpmReady -and $is20) { Add-Result 'TPM 2.0' 'PASS' 'present and ready' }
    elseif (-not $tpm.TpmPresent) { Add-Result 'TPM 2.0' 'FAIL' 'no TPM found' 'Turn on AMD fTPM in the BIOS (Advanced > AMD fTPM configuration).' }
    else { Add-Result 'TPM 2.0' 'FAIL' ("present={0} ready={1} spec={2}" -f $tpm.TpmPresent, $tpm.TpmReady, $spec) 'Open tpm.msc to see why it is not ready. Do not clear the TPM casually.' }
}
catch { Add-Result 'TPM 2.0' 'UNKNOWN' 'needs an elevated shell to read' 'Run this check as administrator.' }

# 4-5. CFG and DEP (system-wide exploit protection)
try {
    $pm = Get-ProcessMitigation -System -ErrorAction Stop
    if ("$($pm.CFG.Enable)" -eq 'OFF') { Add-Result 'CFG' 'FAIL' 'turned off system-wide' 'Windows Security > App & browser control > Exploit protection: set Control flow guard to "Use default (On)".' }
    else { Add-Result 'CFG' 'PASS' ("system setting: {0}" -f $pm.CFG.Enable) }
    $depPolicy = (Get-CimInstance Win32_OperatingSystem).DataExecutionPrevention_SupportPolicy
    if ("$($pm.DEP.Enable)" -eq 'OFF' -or $depPolicy -eq 0) { Add-Result 'DEP' 'FAIL' ("system setting: {0}, policy {1}" -f $pm.DEP.Enable, $depPolicy) 'Run as admin: bcdedit /set {current} nx OptIn, and reset DEP in Exploit protection.' }
    else { Add-Result 'DEP' 'PASS' ("system setting: {0}, policy {1}" -f $pm.DEP.Enable, $depPolicy) }
}
catch { Add-Result 'CFG/DEP' 'UNKNOWN' $_.Exception.Message }

# 6-7. Test signing and kernel debugging
if ($tokens | Where-Object { $_ -match '^TESTSIGNING' }) { Add-Result 'Test signing' 'FAIL' 'on' 'Run as admin: bcdedit /set {current} testsigning off, then reboot.' } else { Add-Result 'Test signing' 'PASS' 'off' }
if ($tokens | Where-Object { $_ -match '^DEBUG' }) { Add-Result 'Kernel debugging' 'FAIL' 'on' 'Run as admin: bcdedit /debug off, then reboot.' } else { Add-Result 'Kernel debugging' 'PASS' 'off' }

# 8. VBS / HVCI (off by MOS design; on only if exp-vbs-on was applied)
if (-not $deviceGuard) { Add-Result 'VBS / HVCI' 'UNKNOWN' 'Device Guard info not available' }
else {
    $hvci = @($deviceGuard.SecurityServicesRunning) -contains 2
    if (-not $vbsRunning) { Add-Result 'VBS / HVCI' 'PASS' 'off (MOS default; Vanguard runs in always-on mode)' }
    else { Add-Result 'VBS / HVCI' 'INFO' ("VBS running, HVCI {0} (exp-vbs-on applied?)" -f $(if ($hvci) { 'on' } else { 'off' })) 'Expected only if you turned VBS on for Vanguard on-demand mode.' }
}

# 9. Hypervisor features
$hvFeatures = 'Microsoft-Hyper-V-All', 'VirtualMachinePlatform', 'Containers-DisposableClientVM', 'Windows-Defender-ApplicationGuard'
$on = @(Get-CimInstance Win32_OptionalFeature -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $hvFeatures -and $_.InstallState -eq 1 } | ForEach-Object Name)
$hvPresent = [bool](Get-CimInstance Win32_ComputerSystem).HypervisorPresent
if ($on.Count) { Add-Result 'Hypervisor features' 'FAIL' ("enabled: {0}" -f ($on -join ', ')) 'Run tune.ps1 apply -Module virtualization, then reboot.' }
elseif ($hvPresent -and -not $vbsRunning) { Add-Result 'Hypervisor features' 'FAIL' 'features off, but a hypervisor is running' 'Run as admin: bcdedit /set hypervisorlaunchtype off, then reboot.' }
else { Add-Result 'Hypervisor features' 'PASS' $(if ($hvPresent) { 'features off (hypervisor running for VBS)' } else { 'off, no hypervisor running' }) }

# 10. Vanguard
$vgk = Get-CimInstance Win32_SystemDriver -Filter "Name='vgk'" -ErrorAction SilentlyContinue
$vgc = Get-CimInstance Win32_Service -Filter "Name='vgc'" -ErrorAction SilentlyContinue
if (-not $vgk -or -not $vgc) { Add-Result 'Vanguard' 'FAIL' 'not installed' 'Install the Riot Client and VALORANT; Vanguard installs with them. Then reboot.' }
elseif ($vgk.State -ne 'Running') { Add-Result 'Vanguard' 'FAIL' ("vgk driver {0}" -f $vgk.State) 'Reboot so the Vanguard driver loads at startup.' }
else { Add-Result 'Vanguard' 'PASS' ("vgk {0}, vgc {1}" -f $vgk.State, $vgc.StartMode) }

if (-not $Quiet) {
    Write-Host ''
    Write-Host 'Riot Vanguard compatibility (read-only)' -ForegroundColor White
    foreach ($r in $results) {
        $c = switch ($r.Status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'DarkYellow' } }
        Write-Host ("  {0,-8} {1,-20} {2}" -f $r.Status, $r.Item, $r.Detail) -ForegroundColor $c
        if ($r.Status -ne 'PASS' -and $r.Hint) { Write-Host ("           -> {0}" -f $r.Hint) -ForegroundColor DarkGray }
    }
    Write-Host ''
}

if ($PassThru) { return $results.ToArray() }
if (@($results | Where-Object Status -eq 'FAIL').Count) { exit 1 } else { exit 0 }
