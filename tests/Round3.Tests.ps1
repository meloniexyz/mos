. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'Round 3 tweaks load and select correctly (tune-round-3 2.1, 2.2)' {
    Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
    Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1') }
    $loaded = Import-MosTweaks
    $all = @($loaded.Tweaks)

    It 'loads every module with nothing rejected' {
        ($loaded.Rejected | ForEach-Object { "$($_.Id): $($_.Reason)" }) -join '; ' | Should Be ''
    }
    It 'puts the new standard tweaks in the default profile' {
        $default = @(Select-MosTweaks -Tweaks $all -State @{} -Command apply | ForEach-Object { $_.Id })
        foreach ($id in 'svc-ai-fabric', 'policy-no-click-to-do', 'policy-no-spotlight', 'power-epp-performance', 'power-boost-aggressive') { $default -contains $id | Should Be $true }
    }
    It 'keeps the new experiments out of the default profile and selectable by id' {
        $default = @(Select-MosTweaks -Tweaks $all -State @{} -Command apply | ForEach-Object { $_.Id })
        foreach ($id in 'exp-sysmain-off', 'exp-memory-compression-off', 'exp-windowed-optimizations') {
            $default -contains $id | Should Be $false
            @(Select-MosTweaks -Tweaks $all -State @{} -Command apply -Id $id).Count | Should Be 1
        }
    }
}

Describe 'dx-global-setting script tweak (tune-round-3 2.2)' {
    AfterEach { Remove-Item 'HKCU:\Software\MOS-test-dx' -Recurse -Force -ErrorAction SilentlyContinue; Clear-MosTestEnv }

    $module = "@{ Tweaks = @( @{ Id = 'dx'; Tier = 'standard'; Type = 'Script'; Script = 'dx-global-setting'; Key = 'SwapEffectUpgradeEnable'; Value = '1'; RegKey = 'HKCU:\Software\MOS-test-dx'; Why = 't' } ) }"

    It 'adds the pair, keeps other pairs, and undo restores the exact string' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\d1" -AsHost
        New-Item 'HKCU:\Software\MOS-test-dx' -Force | Out-Null
        New-ItemProperty 'HKCU:\Software\MOS-test-dx' -Name DirectXUserGlobalSettings -Value 'VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;' -PropertyType String | Out-Null
        Write-MosTestModule $m '10-dx' $module
        (Invoke-MosTune -Command apply).Results[0].Status | Should Be 'applied'
        (Get-Item 'HKCU:\Software\MOS-test-dx').GetValue('DirectXUserGlobalSettings') | Should Be 'VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;'
        $null = Invoke-MosTune -Command undo
        (Get-Item 'HKCU:\Software\MOS-test-dx').GetValue('DirectXUserGlobalSettings') | Should Be 'VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;'
    }
    It 'creates the string when absent and removes it again on undo' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\d2" -AsHost
        Write-MosTestModule $m '10-dx' $module
        $null = Invoke-MosTune -Command apply
        (Get-Item 'HKCU:\Software\MOS-test-dx').GetValue('DirectXUserGlobalSettings') | Should Be 'SwapEffectUpgradeEnable=1;'
        $null = Invoke-MosTune -Command undo
        @((Get-Item 'HKCU:\Software\MOS-test-dx').GetValueNames()) -contains 'DirectXUserGlobalSettings' | Should Be $false
    }
}

Describe 'memory-compression script tweak (tune-round-3 2.2)' {
    It 'reports unknown, not failed, when it cannot read without admin' {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) { Set-TestInconclusive 'running elevated: Get-MMAgent works here' ; return }
        Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
        Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1'); LogDir = (Join-Path $TestDrive 'logs') }
        $r = (Invoke-MosTune -Command check -Id 'exp-memory-compression-off').Results[0]
        $r.Status | Should Be 'unknown'
    }
}
