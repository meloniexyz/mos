. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'Display and scheduling experiments are opt-in (tune-round-2 3.1)' {
    Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
    Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1') }
    $all = @((Import-MosTweaks).Tweaks)

    It 'are not applied by default and are selectable by id' {
        $default = @(Select-MosTweaks -Tweaks $all -State @{} -Command apply | ForEach-Object { $_.Id })
        foreach ($id in 'exp-mpo-off', 'exp-priority-separation', 'exp-fso-off', 'exp-gpu-irq-policy', 'exp-gpu-irq-mask') {
            $default -contains $id | Should Be $false
            @(Select-MosTweaks -Tweaks $all -State @{} -Command apply -Id $id).Count | Should Be 1
        }
        @(Select-MosTweaks -Tweaks $all -State @{} -Command apply -Id 'exp-gpu-irq-*').Count | Should Be 2
    }
    It 'adds the two new standard tweaks to the default profile' {
        $default = @(Select-MosTweaks -Tweaks $all -State @{} -Command apply | ForEach-Object { $_.Id })
        $default -contains 'sac-off' | Should Be $true
        $default -contains 'boot-no-platform-clock' | Should Be $true
    }
}

Describe 'fso-valorant script tweak (tune-round-2 3.2)' {
    AfterEach { Remove-Item 'HKCU:\Software\MOS-test-layers' -Recurse -Force -ErrorAction SilentlyContinue; Clear-MosTestEnv }

    function Write-FsoModule($Dir, $Exe) {
        $e = $Exe.Replace("'", "''")
        Write-MosTestModule $Dir '10-fso' "@{ Tweaks = @( @{ Id = 'fso'; Tier = 'standard'; Type = 'Script'; Script = 'fso-valorant'; ExePath = '$e'; LayersKey = 'HKCU:\Software\MOS-test-layers'; Why = 't' } ) }"
    }

    It 'adds the token, keeps existing tokens and undo restores the exact string' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\f1" -AsHost
        $exe = Join-Path $TestDrive 'f1\VALORANT-Win64-Shipping.exe'; Set-Content $exe 'x'
        New-Item 'HKCU:\Software\MOS-test-layers' -Force | Out-Null
        New-ItemProperty 'HKCU:\Software\MOS-test-layers' -Name $exe -Value '~ HIGHDPIAWARE' -PropertyType String | Out-Null
        Write-FsoModule $m $exe
        (Invoke-MosTune -Command apply).Results[0].Status | Should Be 'applied'
        (Get-Item 'HKCU:\Software\MOS-test-layers').GetValue($exe) | Should Be '~ HIGHDPIAWARE DISABLEDXMAXIMIZEDWINDOWEDMODE'
        $null = Invoke-MosTune -Command undo
        (Get-Item 'HKCU:\Software\MOS-test-layers').GetValue($exe) | Should Be '~ HIGHDPIAWARE'
    }
    It 'removes the value again on undo when there was none' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\f2" -AsHost
        $exe = Join-Path $TestDrive 'f2\VALORANT-Win64-Shipping.exe'; Set-Content $exe 'x'
        Write-FsoModule $m $exe
        $null = Invoke-MosTune -Command apply
        (Get-Item 'HKCU:\Software\MOS-test-layers').GetValue($exe) | Should Be '~ DISABLEDXMAXIMIZEDWINDOWEDMODE'
        $null = Invoke-MosTune -Command undo
        @((Get-Item 'HKCU:\Software\MOS-test-layers').GetValueNames()) -contains $exe | Should Be $false
    }
    It 'is skipped while the game is not installed' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\f3" -AsHost
        Write-FsoModule $m (Join-Path $TestDrive 'f3\missing.exe')
        $r = (Invoke-MosTune -Command apply).Results[0]
        $r.Status | Should Be 'skipped'
        $r.Detail | Should Match 'not installed'
    }
}

Describe 'Binary registry values for GPU interrupt affinity (tune-round-2 3.3)' {
    AfterEach { Remove-Item 'HKCU:\Software\MOS-test-bin' -Recurse -Force -ErrorAction SilentlyContinue }

    It 'converts the declared mask to 8 bytes that read back as equal' {
        Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
        $bytes = & (Get-Module MosTune) { ConvertTo-MosRegValue @(4, 0, 0, 0, 0, 0, 0, 0) 'Binary' }
        $bytes.GetType().Name | Should Be 'Byte[]'
        $bytes.Length | Should Be 8
        New-Item 'HKCU:\Software\MOS-test-bin' -Force | Out-Null
        New-ItemProperty 'HKCU:\Software\MOS-test-bin' -Name Mask -Value $bytes -PropertyType Binary | Out-Null
        $back = (Get-Item 'HKCU:\Software\MOS-test-bin').GetValue('Mask')
        (ConvertTo-MosCanonical $back) | Should Be (ConvertTo-MosCanonical @(4, 0, 0, 0, 0, 0, 0, 0))
        & (Get-Module MosTune) { ConvertTo-MosRegValue 4 'DWord' } | Should Be 4
    }
}

Describe 'Game process scheduling is never touched (tune-round-2 3.4)' {
    AfterEach { Clear-MosTestEnv }

    It 'no module tweak targets process priority, affinity or IFEO' {
        Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
        Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1') }
        foreach ($t in (Import-MosTweaks).Tweaks) {
            "$($t['Target']) $($t['Name'])" | Should Not Match 'Image File Execution Options|PerfOptions|CpuPriorityClass'
            if ("$($t['Target'])" -match 'VALORANT|Riot') { "$($t['Name'])" | Should Not Match 'Affinity|Priority' }
        }
    }
    It 'still rejects an IFEO priority tweak through the real keep-list' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\p1"
        Write-MosTestModule $m '10-ifeo' "@{ Tweaks = @( @{ Id = 'ifeo'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions'; Name = 'CpuPriorityClass'; Value = 3; ValueType = 'DWord'; Why = 't' } ) }"
        $r = Import-MosTweaks
        @($r.Tweaks).Count | Should Be 0
        $r.Rejected[0].Reason | Should Match 'keep-list'
    }
}
