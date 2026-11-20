. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'Bench system counters (tune-round-2 4.1)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bench\bench.ps1')

    It 'samples every 5 s into a CSV and stops cleanly' {
        $out = Join-Path $TestDrive 'run.counters.csv'
        $job = Start-CounterSampler $out 5
        Start-Sleep -Seconds 16
        Stop-CounterSampler $job
        $rows = @(Import-Csv $out)
        $rows.Count | Should BeGreaterThan 1
        $rows.Count | Should BeLessThan 4
        $rows[0].PSObject.Properties.Name -join ',' | Should Be 'time,intPct,dpcPct,busiestCore'
        Get-Job | Where-Object { $_.State -eq 'Running' } | Should BeNullOrEmpty
    }

    # fake PresentMon: writes a small frame-time CSV to the --output_file argument (4th argument)
    $fakePm = Join-Path $TestDrive 'PresentMon-fake.cmd'
    Set-Content $fakePm -Encoding ASCII -Value @(
        '@echo off',
        '> "%~4" echo Application,MsBetweenPresents',
        'for /L %%i in (1,1,50) do >> "%~4" echo test.exe,5.0'
    )

    It 'starts no sampler without -WithCounters' {
        Mock Start-CounterSampler { throw 'sampler must not start' }
        $Command = 'capture'; $Label = @('nocount'); $Seconds = 1; $WaitTimeout = 5; $ProcessName = 'powershell'
        $PresentMon = $fakePm; $WithCounters = $false; $ResultsDir = Join-Path $TestDrive 'r1'
        $null = Invoke-Bench 6>$null
        Assert-MockCalled Start-CounterSampler -Times 0 -Exactly
        @(Get-ChildItem $ResultsDir -Filter '*.counters.csv').Count | Should Be 0
    }
    It 'starts and stops one sampler with -WithCounters' {
        Mock Start-CounterSampler { 'fake-job' }
        Mock Stop-CounterSampler { }
        $Command = 'capture'; $Label = @('withcount'); $Seconds = 1; $WaitTimeout = 5; $ProcessName = 'powershell'
        $PresentMon = $fakePm; $WithCounters = $true; $ResultsDir = Join-Path $TestDrive 'r2'
        $null = Invoke-Bench 6>$null
        Assert-MockCalled Start-CounterSampler -Times 1 -Exactly
        Assert-MockCalled Stop-CounterSampler -Times 1 -Exactly
    }
}

Describe 'Bench counter summary and compare (tune-round-2 4.2)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bench\bench.ps1')

    It 'adds counter fields only when a counters file exists' {
        $dir = Join-Path $TestDrive 's'; New-Item -ItemType Directory $dir | Out-Null
        $frames = @('Application,MsBetweenPresents') + (@('x,5.0') * 100)
        Set-Content (Join-Path $dir 'a-with.csv') $frames
        Set-Content (Join-Path $dir 'a-with.counters.csv') @('time,intPct,dpcPct,busiestCore', '00:00:01,1.00,2.00,80.00', '00:00:06,3.00,4.00,90.00', '00:00:11,2.00,3.00,85.00')
        Set-Content (Join-Path $dir 'b-without.csv') $frames
        $with = Save-Summary (Join-Path $dir 'a-with.csv') 'with'
        $without = Save-Summary (Join-Path $dir 'b-without.csv') 'without'
        $with.IntPctMed | Should Be 2
        $with.DpcPctMed | Should Be 3
        $with.BusiestCoreMed | Should Be 85
        $with.CounterSamples | Should Be 3
        [bool]$without.PSObject.Properties['IntPctMed'] | Should Be $false
    }
    It 'reports a drop in DPC time as a gain and skips counters for runs without them' {
        $sums = @(
            [pscustomobject]@{ Label = 'base'; AvgFps = 200; Low1 = 120; Low01 = 90; IntPctMed = 1.0; DpcPctMed = 2.0 }
            [pscustomobject]@{ Label = 'irq'; AvgFps = 201; Low1 = 121; Low01 = 90; IntPctMed = 1.0; DpcPctMed = 1.0 }
            [pscustomobject]@{ Label = 'plain'; AvgFps = 200; Low1 = 120; Low01 = 90 }
        )
        $c = Compare-Bench $sums @('base', 'irq', 'plain')
        ($c | Where-Object { $_.Label -eq 'irq' -and $_.Metric -eq 'DpcPctMed' }).Verdict | Should Be 'gain'
        ($c | Where-Object { $_.Label -eq 'irq' -and $_.Metric -eq 'IntPctMed' }).Verdict | Should Be 'within noise'
        @($c | Where-Object { $_.Label -eq 'plain' -and $_.Metric -like '*PctMed' }).Count | Should Be 0
        @($c | Where-Object { $_.Label -eq 'plain' -and $_.Metric -eq 'AvgFps' }).Count | Should Be 1
    }
}
