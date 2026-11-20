. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
. (Join-Path $script:RepoRoot 'usb\MOS\doctor.ps1')

function Get-Item1($Results, $Item) { $Results | Where-Object { $_.Item -eq $Item } }

Describe 'Doctor rules with injected readings (tune-round-3 1.1)' {
    It 'warns when the RAM profile is off, rated speed from the part number' {
        $r = Test-DocRam @([pscustomobject]@{ PartNumber = 'XX4-3200C16-16GTEST'; Speed = 2133; Configured = 2133 })
        $r.Status | Should Be 'WARN'
        $r.Detail | Should Match '2133.*3200.*part number'
        $r.Hint | Should Match 'XMP / DOCP'
    }
    It 'passes when RAM runs at rated speed, and ignores part numbers without a speed' {
        (Test-DocRam @([pscustomobject]@{ PartNumber = 'XX4-3200C16-16GTEST'; Speed = 3200; Configured = 3200 })).Status | Should Be 'PASS'
        (Test-DocRam @([pscustomobject]@{ PartNumber = 'KF432C16BB/8'; Speed = 3200; Configured = 3200 })).Status | Should Be 'PASS'
        (Test-DocRam @([pscustomobject]@{ PartNumber = 'KF432C16BB/8'; Speed = 3200; Configured = 2400 })).Status | Should Be 'WARN'
        Get-RatedFromPartNumber 'CMK16GX4M2B3200C16' | Should Be 3200
        Get-RatedFromPartNumber 'BL16G32C16U4B' | Should BeNullOrEmpty
    }
    It 'warns about a display below its max refresh, tolerates 239 vs 240' {
        (Test-DocDisplay ([pscustomobject]@{ Current = 60; Max = 240; Source = 't' })).Status | Should Be 'WARN'
        (Test-DocDisplay ([pscustomobject]@{ Current = 239; Max = 240; Source = 't' })).Status | Should Be 'PASS'
        (Test-DocDisplay $null).Status | Should Be 'UNKNOWN'
    }
    It 'warns about a narrowed GPU link' {
        (Test-DocGpuLink ([pscustomobject]@{ Width = 8; MaxWidth = 16 })).Status | Should Be 'WARN'
        (Test-DocGpuLink ([pscustomobject]@{ Width = 16; MaxWidth = 16 })).Status | Should Be 'PASS'
        (Test-DocGpuLink $null).Status | Should Be 'INFO'
    }
    It 'checks plan, MSI, Game Mode, pending restart and free space' {
        (Test-DocPowerPlan ([pscustomobject]@{ Guid = '4d4f5300-0000-4000-8000-000000000001'; Name = 'MOS' })).Status | Should Be 'PASS'
        (Test-DocPowerPlan ([pscustomobject]@{ Guid = '381b4222-f694-41f0-9685-ff5bb260df2e'; Name = 'Balanced' })).Status | Should Be 'WARN'
        (Test-DocMsi ([pscustomobject]@{ Irq = 4294967280 })).Status | Should Be 'PASS'
        (Test-DocMsi ([pscustomobject]@{ Irq = -16 })).Status | Should Be 'PASS'
        (Test-DocMsi ([pscustomobject]@{ Irq = 54 })).Status | Should Be 'WARN'
        (Test-DocGameMode ([pscustomobject]@{ Enabled = $false })).Status | Should Be 'WARN'
        (Test-DocGameMode ([pscustomobject]@{ Enabled = $true })).Status | Should Be 'PASS'
        (Test-DocPendingReboot $true).Status | Should Be 'WARN'
        (Test-DocPendingReboot $false).Status | Should Be 'PASS'
        (Test-DocFreeSpace 12.5).Status | Should Be 'WARN'
        (Test-DocFreeSpace 120).Status | Should Be 'PASS'
    }
    It 'reports driver age as INFO, WARN past 180 days' {
        (Test-DocDriverAge ([pscustomobject]@{ Version = '1'; Date = (Get-Date).AddDays(-30); Days = 30 })).Status | Should Be 'INFO'
        (Test-DocDriverAge ([pscustomobject]@{ Version = '1'; Date = (Get-Date).AddDays(-400); Days = 400 })).Status | Should Be 'WARN'
    }
    It 'names background programs above 2% of a core' {
        $r = Test-DocBackground @([pscustomobject]@{ Name = 'browser'; PctCore = 30.5 }, [pscustomobject]@{ Name = 'tiny'; PctCore = 0.4 })
        $r.Status | Should Be 'WARN'
        $r.Detail | Should Match 'browser 30\.5%'
        $r.Detail | Should Not Match 'tiny'
        (Test-DocBackground @()).Status | Should Be 'PASS'
    }
    It 'runs every check from injected readings, one result each' {
        $res = @(Invoke-MosDoctor -Readings @{
                Ram = @([pscustomobject]@{ PartNumber = 'x'; Speed = 3200; Configured = 3200 }); Display = [pscustomobject]@{ Current = 240; Max = 240; Source = 't' }
                GpuLink = [pscustomobject]@{ Width = 16; MaxWidth = 16 }; PowerPlan = [pscustomobject]@{ Guid = '4d4f5300-0000-4000-8000-000000000001'; Name = 'MOS' }
                Msi = [pscustomobject]@{ Irq = -16 }; GameMode = [pscustomobject]@{ Enabled = $true }; PendingReboot = $false; FreeSpace = 200
                DriverAge = [pscustomobject]@{ Version = '1'; Date = (Get-Date); Days = 1 }; Background = @()
            })
        $res.Count | Should Be 10
        @($res | Where-Object { $_.Status -eq 'WARN' }).Count | Should Be 0
    }
    It 'turns a failing reader into UNKNOWN instead of stopping' {
        function Get-DocFreeSpace { throw 'disk gone' }
        $res = @(Invoke-MosDoctor -Readings @{ Background = @() })
        (Get-Item1 $res 'FreeSpace').Status | Should Be 'UNKNOWN'
    }
}
