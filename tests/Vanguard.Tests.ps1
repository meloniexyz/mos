. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'vanguard-check.ps1 (5.1)' {
    It 'returns one result per item and changes nothing' {
        $r = & (Join-Path $script:RepoRoot 'usb\MOS\vanguard-check.ps1') -PassThru -Quiet
        $items = $r | ForEach-Object { $_.Item }
        foreach ($i in 'Windows 11', 'Secure Boot', 'TPM 2.0', 'Test signing', 'Kernel debugging', 'VBS / HVCI', 'Hypervisor features', 'Vanguard') { $items -contains $i | Should Be $true }
        $r | ForEach-Object { $_.Status | Should Match '^(PASS|FAIL|INFO|UNKNOWN)$' }
    }
}

Describe 'Vanguard check after apply (5.2)' {
    AfterEach { Clear-MosTestEnv }

    It 'surfaces a DEP failure in the run summary' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\v1" -AsHost
        Write-MosTestModule $m '10-fake' "@{ Tweaks = @( @{ Id = 'f'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 't' } ) }"
        Set-MosConfig @{ VanguardCheck = { @([pscustomobject]@{ Item = 'DEP'; Status = 'FAIL'; Detail = 'turned off' }, [pscustomobject]@{ Item = 'CFG'; Status = 'PASS'; Detail = 'on' }) } }
        $run = Invoke-MosTune -Command apply
        @($run.VanguardFailures).Count | Should Be 1
        $run.VanguardFailures[0].Item | Should Be 'DEP'
        (Get-Content $run.LogPath -Raw) | Should Match 'VANGUARD FAIL\s+DEP'
    }
    It 'does not run the check for dry runs or check' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\v2" -AsHost
        Write-MosTestModule $m '10-fake' "@{ Tweaks = @( @{ Id = 'f'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 't' } ) }"
        Set-MosConfig @{ VanguardCheck = { throw 'should not run' } }
        @((Invoke-MosTune -Command apply -DryRun).Vanguard).Count | Should Be 0
        @((Invoke-MosTune -Command check).Vanguard).Count | Should Be 0
    }
}
