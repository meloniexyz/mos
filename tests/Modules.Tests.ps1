. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1') }

$loaded = Import-MosTweaks
$all = @($loaded.Tweaks)
$experimental = @($all | Where-Object { $_.Tier -eq 'experimental' })

Describe 'Real tuning modules (4.1-4.4)' {
    It 'load with no rejected tweaks (no keep-list conflicts, valid schema)' {
        ($loaded.Rejected | ForEach-Object { "$($_.Id): $($_.Reason)" }) -join '; ' | Should Be ''
        $all.Count | Should BeGreaterThan 100
    }
    It 'cover every module named in the spec' {
        $mods = $all | ForEach-Object { $_.Module } | Sort-Object -Unique
        foreach ($m in 'apps', 'services', 'tasks', 'power', 'network', 'gpu', 'game', 'virtualization', 'experimental') { $mods -contains $m | Should Be $true }
    }
    It 'keep WebView2, VC++ runtimes and the Store out of app removal' {
        $apps = @($all | Where-Object { $_.Type -eq 'Appx' } | ForEach-Object { $_.Target })
        foreach ($a in $apps) { $a | Should Not Match 'WebView|VCLibs|WindowsStore|DesktopAppInstaller|SecHealthUI' }
    }
    It 'never disable CPU idle states in the power plan' {
        $idleDisable = '5d76a2ca-e8c0-402f-a133-2158492d58ad'
        @($all | Where-Object { $_.Type -eq 'PowerSetting' -and $_.Setting -eq $idleDisable }).Count | Should Be 0
    }
    It 'set every VALORANT graphics group to its lowest value' {
        $ini = $all | Where-Object { $_.Id -eq 'valorant-low-graphics' }
        foreach ($k in 'sg.ViewDistanceQuality', 'sg.AntiAliasingQuality', 'sg.ShadowQuality', 'sg.GlobalIlluminationQuality', 'sg.ReflectionQuality',
            'sg.PostProcessQuality', 'sg.TextureQuality', 'sg.EffectsQuality', 'sg.FoliageQuality', 'sg.ShadingQuality') {
            $ini.Settings[$k] | Should Be '0'
        }
    }
    It 'never apply an experimental tweak by default' {
        $sel = Select-MosTweaks -Tweaks $all -State @{} -Command apply
        @($sel | Where-Object { $_.Tier -eq 'experimental' }).Count | Should Be 0
        @($sel).Count | Should Be ($all.Count - $experimental.Count)
        @(Select-MosTweaks -Tweaks $all -State @{} -Command apply -Module experimental).Count | Should Be 0
    }
    It 'apply an experimental group only when selected by id' {
        $sel = @(Select-MosTweaks -Tweaks $all -State @{} -Command apply -Id 'exp-spectre-*')
        ($sel | ForEach-Object { $_.Id } | Sort-Object) -join ',' | Should Be 'exp-spectre-mask,exp-spectre-override'
    }
    It 'have no experimental tweak touching CFG, DEP or exploit protections' {
        foreach ($t in $experimental) {
            if ($t.Type -eq 'Registry') {
                $t.Name | Should Not Match 'Mitigation|ExceptionChain|MoveImages|SEHOP'
                $t.Target | Should Not Match 'Image File Execution Options'
            }
            if ($t.Type -eq 'Bcd') { $t.Target | Should Not Be 'nx' }
        }
    }
    It 'include the speculative-execution, HAGS, timer and VBS-on experiments' {
        foreach ($p in 'exp-spectre-*', 'exp-hags-*', 'exp-timer-*', 'exp-vbs-on-*', 'exp-defender-quiet') {
            @($experimental | Where-Object { $_.Id -like $p }).Count | Should BeGreaterThan 0
        }
    }
}
