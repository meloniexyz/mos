. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'Bench environment snapshot (tune-round-3 3.1)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bench\bench.ps1')

    It 'reads a snapshot with every field, including applied experiments from state' {
        $state = Join-Path $TestDrive 'state.json'
        Set-Content $state '{"exp-hags-off":{"tweak":{"Tier":"experimental"}},"svc-search":{"tweak":{"Tier":"standard"}},"exp-mpo-off":{"tweak":{"Tier":"experimental"}}}'
        $script:BenchStatePath = $state
        $e = Get-BenchEnv
        foreach ($f in 'RamMts', 'RefreshHz', 'PowerPlan', 'GpuDriver', 'ExperimentalApplied', 'PendingRestart') { [bool]$e.PSObject.Properties[$f] | Should Be $true }
        ($e.ExperimentalApplied -join ',') | Should Be 'exp-hags-off,exp-mpo-off'
        $e.RamMts | Should BeGreaterThan 0
    }
    It 'saves the snapshot inside the run summary' {
        $dir = Join-Path $TestDrive 'r'; New-Item -ItemType Directory $dir | Out-Null
        Set-Content (Join-Path $dir 'x.csv') (@('Application,MsBetweenPresents') + (@('a,5.0') * 20))
        $snap = [pscustomobject]@{ RamMts = 3200; RefreshHz = 240; PowerPlan = 'p'; GpuDriver = 'd'; ExperimentalApplied = @(); PendingRestart = $false }
        $null = Save-Summary (Join-Path $dir 'x.csv') 'x' $snap
        $back = Get-Content (Join-Path $dir 'x.summary.json') -Raw | ConvertFrom-Json
        $back.Env.RamMts | Should Be 3200
        $back.Env.RefreshHz | Should Be 240
    }

    $base = [pscustomobject]@{ RamMts = 3200; RefreshHz = 240; PowerPlan = 'mos'; GpuDriver = '1'; ExperimentalApplied = @(); PendingRestart = $false }

    It 'flags a RAM speed change as not comparable' {
        $run = [pscustomobject]@{ RamMts = 2133; RefreshHz = 240; PowerPlan = 'mos'; GpuDriver = '1'; ExperimentalApplied = @(); PendingRestart = $false }
        $d = Get-BenchEnvDiff $base $run
        ($d.Critical -join ';') | Should Match 'RamMts 3200 -> 2133'
        $d.Info.Count | Should Be 0
    }
    It 'treats a different experiment set as information only, and 239 vs 240 Hz as equal' {
        $run = [pscustomobject]@{ RamMts = 3200; RefreshHz = 239; PowerPlan = 'mos'; GpuDriver = '1'; ExperimentalApplied = @('exp-hags-off'); PendingRestart = $false }
        $d = Get-BenchEnvDiff $base $run
        $d.Critical.Count | Should Be 0
        ($d.Info -join ';') | Should Match 'exp-hags-off'
    }
    It 'notes a missing snapshot and still compares the frame metrics' {
        (Get-BenchEnvDiff $base $null).Missing | Should Be $true
        $sums = @(
            [pscustomobject]@{ Label = 'old'; AvgFps = 200; Low1 = 120; Low01 = 90 }
            [pscustomobject]@{ Label = 'new'; AvgFps = 230; Low1 = 140; Low01 = 100; Env = $base }
        )
        $rows = Compare-Bench $sums @('old', 'new') 6>$null
        @($rows | Where-Object { $_.Metric -eq 'AvgFps' }).Count | Should Be 1
    }
    It 'prints the not-comparable warning in compare' {
        $sums = @(
            [pscustomobject]@{ Label = 'a'; AvgFps = 200; Low1 = 120; Low01 = 90; Env = $base }
            [pscustomobject]@{ Label = 'b'; AvgFps = 180; Low1 = 100; Low01 = 80; Env = [pscustomobject]@{ RamMts = 2133; RefreshHz = 240; PowerPlan = 'mos'; GpuDriver = '1'; ExperimentalApplied = @(); PendingRestart = $false } }
        )
        $w = @(Compare-Bench $sums @('a', 'b') 3>&1 6>$null | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        ($w | ForEach-Object { $_.Message }) -join ' ' | Should Match 'NOT comparable.*RamMts'
    }
}
