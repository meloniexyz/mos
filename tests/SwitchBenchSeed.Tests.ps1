. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'Boot switch entry matching (7.1)' {
    . (Join-Path $script:RepoRoot 'windows10\play-valorant.ps1')
    $win10 = @('Windows Boot Loader', '-------------------', 'identifier              {aaaaaaaa-1111-2222-3333-444444444444}', 'device                  partition=C:', 'description             Windows 10', '')
    $mos = @('Windows Boot Loader', '-------------------', 'identifier              {bbbbbbbb-1111-2222-3333-444444444444}', 'device                  partition=E:', 'description             MOS', '')
    $mos2 = @('Windows Boot Loader', '-------------------', 'identifier              {cccccccc-1111-2222-3333-444444444444}', 'description             MOS', '')

    It 'finds exactly one MOS entry' {
        $r = Find-MosBootEntry ($win10 + $mos)
        $r.Status | Should Be 'ok'
        $r.Entry.Identifier | Should Be '{bbbbbbbb-1111-2222-3333-444444444444}'
    }
    It 'reports a missing entry without picking anything' {
        $r = Find-MosBootEntry $win10
        $r.Status | Should Be 'missing'
        $r.Entry | Should BeNullOrEmpty
    }
    It 'refuses when two entries share the name' {
        $r = Find-MosBootEntry ($win10 + $mos + $mos2)
        $r.Status | Should Be 'ambiguous'
        $r.Message | Should Match 'bbbbbbbb.*cccccccc'
    }
    It 'does not match a partial name' {
        (Find-MosBootEntry ($win10 + @('identifier {dddddddd-1111-2222-3333-444444444444}', 'description MOS old'))).Status | Should Be 'missing'
    }
}

Describe 'Bench capture helpers (8.1)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bench\bench.ps1')

    It 'builds PresentMon arguments for the game process and duration' {
        $a = New-PresentMonArgs 'VALORANT-Win64-Shipping' 'C:\r\x.csv' 120
        ($a -join ' ') | Should Be '--process_name VALORANT-Win64-Shipping.exe --output_file C:\r\x.csv --timed 120 --terminate_after_timed --stop_existing_session'
    }
    It 'times out when the game never starts' {
        Wait-ForProcess 'no-such-process-mos' 1 1 | Should Be $false
    }
    It 'gives a clear message when PresentMon is missing' {
        { Find-PresentMon (Join-Path $TestDrive 'nope.exe') } | Should Throw 'PresentMon not found'
    }
}

Describe 'Bench summary and compare (8.2)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bench\bench.ps1')

    function New-Csv([string]$Path, [string]$Column, [double[]]$Times) {
        $lines = @("Application,$Column") + ($Times | ForEach-Object { "VALORANT-Win64-Shipping.exe,{0}" -f $_.ToString([Globalization.CultureInfo]::InvariantCulture) })
        Set-Content -Path $Path -Value $lines
    }

    It 'computes avg, 1% and 0.1% lows from known frame times (either column name)' {
        # 990 frames at 4 ms, 9 at 10 ms, 1 at 20 ms
        $t = @(@(4.0) * 990 + @(10.0) * 9 + @(20.0))
        foreach ($col in 'MsBetweenPresents', 'FrameTime') {
            $csv = Join-Path $TestDrive "k-$col.csv"
            New-Csv $csv $col $t
            $s = Get-FrameStats (Get-FrameTimes $csv)
            $s.Frames | Should Be 1000
            $s.AvgFps | Should Be ([math]::Round(1000 / ((990 * 4 + 90 + 20) / 1000), 1))
            $s.P99Ms | Should Be 4            # plain 99th percentile sits just below the stutters...
            $s.Low1 | Should Be 90.9          # ...so 1% low averages the slowest 10 frames: (9x10 + 20) / 10 = 11 ms
            $s.Low01 | Should Be 50           # slowest 1 frame: 20 ms
        }
    }
    It 'flags a change within run-to-run noise and a real gain' {
        $sums = @(
            [pscustomobject]@{ Label = 'baseline'; AvgFps = 200; Low1 = 120; Low01 = 90 }
            [pscustomobject]@{ Label = 'baseline'; AvgFps = 206; Low1 = 123; Low01 = 92 }
            [pscustomobject]@{ Label = 'small'; AvgFps = 208; Low1 = 124; Low01 = 92 }
            [pscustomobject]@{ Label = 'big'; AvgFps = 240; Low1 = 150; Low01 = 110 }
        )
        $c = Compare-Bench $sums @('baseline', 'small', 'big')
        ($c | Where-Object { $_.Label -eq 'small' -and $_.Metric -eq 'AvgFps' }).Verdict | Should Be 'within noise'
        ($c | Where-Object { $_.Label -eq 'big' -and $_.Metric -eq 'Low1' }).Verdict | Should Be 'gain'
        ($c | Where-Object { $_.Label -eq 'big' -and $_.Metric -eq 'AvgFps' }).NoisePct | Should Be 3
    }
    It 'saves a summary next to the capture and reads it back by label' {
        $dir = Join-Path $TestDrive 'results'; New-Item -ItemType Directory $dir | Out-Null
        $csv = Join-Path $dir '20261120-120000-baseline.csv'
        New-Csv $csv 'MsBetweenPresents' (@(5.0) * 200)
        $null = Save-Summary $csv 'baseline'
        $s = Get-Summaries $dir
        @($s).Count | Should Be 1
        $s[0].Label | Should Be 'baseline'
        $s[0].AvgFps | Should Be 200
    }
}

Describe 'seed-valorant.ps1 (9.1)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\seed-valorant.ps1')

    It 'finds VALORANT folders on other drives, never the system drive' {
        $d = Join-Path $TestDrive 'drive\'
        New-Item -ItemType Directory (Join-Path $d 'Riot Games\VALORANT\live') -Force | Out-Null
        @(Find-ValorantSources @($d)).Count | Should Be 1
        @(Find-ValorantSources @("$env:SystemDrive\")).Count | Should Be 0
    }
    It 'previews a copy with robocopy /L and copies nothing' {
        $Source = Join-Path $TestDrive 'src'
        New-Item -ItemType Directory (Join-Path $Source 'live') -Force | Out-Null
        Set-Content (Join-Path $Source 'live\pak.bin') 'data'
        $Target = Join-Path $TestDrive 'dst'
        $DryRun = $true
        $code = Invoke-Seed 6>$null | Select-Object -Last 1
        $code | Should BeLessThan 8
        Test-Path (Join-Path $Target 'live\pak.bin') | Should Be $false
    }
    It 'refuses a real copy outside MOS' {
        $Source = Join-Path $TestDrive 'src'; $Target = Join-Path $TestDrive 'dst2'; $DryRun = $false
        { Invoke-Seed } | Should Throw 'only runs there'
    }
}
