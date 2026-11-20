. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$fakeModule = @'
@{ Tweaks = @(
  @{ Id = 'fake-a'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 'test' }
  @{ Id = 'fake-b'; Tier = 'standard'; Type = 'Fake'; Target = 'b'; Value = 'on'; Why = 'test' }
  @{ Id = 'fake-exp'; Tier = 'experimental'; Type = 'Fake'; Target = 'x'; Value = 5; Why = 'test' }
) }
'@

Describe 'Host guard and admin check (2.1)' {
    AfterEach { Clear-MosTestEnv }

    It 'refuses apply without the host marker' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\g1"
        Write-MosTestModule $m '10-fake' $fakeModule
        { Invoke-MosTune -Command apply } | Should Throw 'only runs on MOS'
        $global:MosFakeStore.Count | Should Be 0
    }
    It 'refuses undo without the host marker' {
        $null = Initialize-MosTestEnv -Root "$TestDrive\g2"
        { Invoke-MosTune -Command undo } | Should Throw 'only runs on MOS'
    }
    It 'refuses apply on MOS without admin rights' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\g3" -AsHost -NotAdmin
        Write-MosTestModule $m '10-fake' $fakeModule
        { Invoke-MosTune -Command apply } | Should Throw 'administrator'
    }
    It 'allows check and dry run without the marker, changing nothing' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\g4"
        Write-MosTestModule $m '10-fake' $fakeModule
        (Invoke-MosTune -Command check).Results.Count | Should Be 2
        (Invoke-MosTune -Command apply -DryRun).Results | ForEach-Object { $_.Status | Should Be 'would-change' }
        $global:MosFakeStore.Count | Should Be 0
        Test-Path "$TestDrive\g4\state\state.json" | Should Be $false
    }
    It 'detects the host only when both file and registry marker exist' {
        $null = Initialize-MosTestEnv -Root "$TestDrive\g5" -AsHost
        Test-MosHost | Should Be $true
        Remove-Item "$TestDrive\g5\.mos-host"
        Test-MosHost | Should Be $false
    }
}

Describe 'Module loading and schema (2.2)' {
    AfterEach { Clear-MosTestEnv }

    It 'reports malformed tweaks and loads the valid ones' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\s1"
        Write-MosTestModule $m '10-mixed' @'
@{ Tweaks = @(
  @{ Id = 'good-one'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 'ok' }
  @{ Id = 'no-why'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1 }
  @{ Id = 'Bad_Id'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 'x' }
  @{ Id = 'bad-tier'; Tier = 'maybe'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 'x' }
  @{ Id = 'bad-type'; Tier = 'standard'; Type = 'Nope'; Target = 'a'; Why = 'x' }
  @{ Id = 'bad-svc'; Tier = 'standard'; Type = 'Service'; Target = 'Foo'; Value = 'Off'; Why = 'x' }
  @{ Id = 'reg-no-type'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\X'; Name = 'n'; Value = 1; Why = 'x' }
  @{ Id = 'good-one'; Tier = 'standard'; Type = 'Fake'; Target = 'b'; Value = 1; Why = 'dup' }
) }
'@
        Write-MosTestModule $m '20-broken' '@{ Tweaks = @( this is not valid'
        $r = Import-MosTweaks
        @($r.Tweaks).Count | Should Be 1
        $r.Tweaks[0].Id | Should Be 'good-one'
        $r.Tweaks[0].Module | Should Be 'mixed'
        @($r.Rejected).Count | Should Be 8
        ($r.Rejected | Where-Object Id -eq 'no-why').Reason | Should Match "missing field 'Why'"
        ($r.Rejected | Where-Object Id -eq 'bad-svc').Reason | Should Match 'not allowed'
        ($r.Rejected | Where-Object Reason -like '*duplicate*').Id | Should Be 'good-one'
        ($r.Rejected | Where-Object Id -eq '<20-broken.psd1>').Reason | Should Match 'cannot parse'
    }
}

Describe 'Keep-list enforcement (2.3)' {
    AfterEach { Clear-MosTestEnv }

    It 'rejects tweaks on protected services, keys and values, and still loads the rest' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\k1"
        Write-MosTestModule $m '10-keep' @'
@{ Tweaks = @(
  @{ Id = 'k-bfe'; Tier = 'standard'; Type = 'Service'; Target = 'BFE'; Value = 'Disabled'; Why = 'x' }
  @{ Id = 'k-mpssvc'; Tier = 'standard'; Type = 'Service'; Target = 'mpssvc'; Value = 'Disabled'; Why = 'x' }
  @{ Id = 'k-crypt'; Tier = 'standard'; Type = 'Service'; Target = 'CryptSvc'; Value = 'Manual'; Why = 'x' }
  @{ Id = 'k-wmi'; Tier = 'standard'; Type = 'Service'; Target = 'Winmgmt'; Value = 'Disabled'; Why = 'x' }
  @{ Id = 'k-wu'; Tier = 'standard'; Type = 'Service'; Target = 'wuauserv'; Value = 'Disabled'; Why = 'x' }
  @{ Id = 'k-cfg'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'; Name = 'MitigationOptions'; Value = 0; ValueType = 'QWord'; Why = 'x' }
  @{ Id = 'k-ci'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'x'; Value = 0; ValueType = 'DWord'; Why = 'x' }
  @{ Id = 'k-svc-reg'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Services\BFE'; Name = 'Start'; Value = 4; ValueType = 'DWord'; Why = 'x' }
  @{ Id = 'k-nx'; Tier = 'standard'; Type = 'Bcd'; Target = 'nx'; Value = 'AlwaysOff'; Why = 'x' }
  @{ Id = 'k-webview'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.WebView2Runtime'; Why = 'x' }
  @{ Id = 'k-wu-task'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\WindowsUpdate\Scheduled Start'; Value = 'Disabled'; Why = 'x' }
  @{ Id = 'allowed-search'; Tier = 'standard'; Type = 'Service'; Target = 'WSearch'; Value = 'Disabled'; Why = 'x' }
) }
'@
        $r = Import-MosTweaks
        @($r.Rejected).Count | Should Be 11
        $r.Rejected | ForEach-Object { $_.Reason | Should Match 'keep-list' }
        @($r.Tweaks).Count | Should Be 1
        $r.Tweaks[0].Id | Should Be 'allowed-search'
    }
}

Describe 'State store (2.4)' {
    AfterEach { Clear-MosTestEnv }

    It 'keeps the original value when apply runs again after a reset' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\st1" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $global:MosFakeStore['a'] = 'original'
        $null = Invoke-MosTune -Command apply
        $global:MosFakeStore['a'] | Should Be 1
        $global:MosFakeStore['a'] = 'windows-update-reset'
        $null = Invoke-MosTune -Command apply
        $s = Read-MosState
        $s['fake-a'].before.Value | Should Be 'original'
        $s['fake-b'].before.Absent | Should Be $true
    }
    It 'recovers from a corrupted state file using the backup' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\st2" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $null = Invoke-MosTune -Command apply
        $null = Invoke-MosTune -Command apply   # creates a backup of the good state
        Set-Content "$TestDrive\st2\state\state.json" -Value '{ this is broken'
        $s = Read-MosState 3>$null
        $s.ContainsKey('fake-a') | Should Be $true
    }
    It 'writes no temp file next to the state after saving' {
        $null = Initialize-MosTestEnv -Root "$TestDrive\st3" -AsHost
        Write-MosState @{ x = @{ before = @{ Absent = $true } } }
        Write-MosState @{ y = @{ before = @{ Absent = $true } } }
        Test-Path "$TestDrive\st3\state\state.json.tmp" | Should Be $false
        (Read-MosState).ContainsKey('y') | Should Be $true
    }
}

Describe 'Runner (2.5)' {
    AfterEach { Clear-MosTestEnv }

    It 'default apply skips experimental tweaks; selecting by id applies them' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r1" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $run = Invoke-MosTune -Command apply
        ($run.Results.Id -contains 'fake-exp') | Should Be $false
        $global:MosFakeStore.ContainsKey('x') | Should Be $false
        $run2 = Invoke-MosTune -Command apply -Id 'fake-e*'
        @($run2.Results).Count | Should Be 1
        $global:MosFakeStore['x'] | Should Be 5
    }
    It 'dry run changes nothing and writes no state' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r2" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $run = Invoke-MosTune -Command apply -DryRun
        @($run.Results | Where-Object Status -eq 'would-change').Count | Should Be 2
        $global:MosFakeStore.Count | Should Be 0
        Test-Path "$TestDrive\r2\state\state.json" | Should Be $false
    }
    It 'keeps going when one tweak fails and logs it' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r3" -AsHost
        Write-MosTestModule $m '10-fake' @'
@{ Tweaks = @(
  @{ Id = 'first'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 't' }
  @{ Id = 'broken'; Tier = 'standard'; Type = 'Fake'; Target = 'explode'; Value = 1; Why = 't' }
  @{ Id = 'last'; Tier = 'standard'; Type = 'Fake'; Target = 'c'; Value = 3; Why = 't' }
) }
'@
        $run = Invoke-MosTune -Command apply
        ($run.Results | Where-Object Id -eq 'broken').Status | Should Be 'failed'
        $global:MosFakeStore['c'] | Should Be 3
        (Get-Content $run.LogPath -Raw) | Should Match 'FAILED\s+broken'
    }
    It 'undo restores recorded values and deletes values that were absent' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r4" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $global:MosFakeStore['a'] = 'original'
        $null = Invoke-MosTune -Command apply
        $run = Invoke-MosTune -Command undo
        @($run.Results | Where-Object Status -eq 'restored').Count | Should Be 2
        $global:MosFakeStore['a'] | Should Be 'original'
        $global:MosFakeStore.ContainsKey('b') | Should Be $false
        (Read-MosState).Count | Should Be 0
    }
    It 'undo by module leaves other modules applied' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r5" -AsHost
        Write-MosTestModule $m '10-one' "@{ Tweaks = @( @{ Id = 'one'; Tier = 'standard'; Type = 'Fake'; Target = 'p'; Value = 1; Why = 't' } ) }"
        Write-MosTestModule $m '20-two' "@{ Tweaks = @( @{ Id = 'two'; Tier = 'standard'; Type = 'Fake'; Target = 'q'; Value = 2; Why = 't' } ) }"
        $null = Invoke-MosTune -Command apply
        $null = Invoke-MosTune -Command undo -Module one
        $global:MosFakeStore.ContainsKey('p') | Should Be $false
        $global:MosFakeStore['q'] | Should Be 2
    }
    It 'check reports drift without changing anything' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r6" -AsHost
        Write-MosTestModule $m '10-fake' $fakeModule
        $null = Invoke-MosTune -Command apply
        $global:MosFakeStore['a'] = 'reset-by-update'
        $run = Invoke-MosTune -Command check
        ($run.Results | Where-Object Id -eq 'fake-a').Status | Should Be 'drift'
        ($run.Results | Where-Object Id -eq 'fake-b').Status | Should Be 'ok'
        $global:MosFakeStore['a'] | Should Be 'reset-by-update'
    }
    It 'check marks a tweak unknown when reading it fails' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\r7"
        Write-MosTestModule $m '10-fake' "@{ Tweaks = @( @{ Id = 'unreadable'; Tier = 'standard'; Type = 'Fake'; Target = 'explode-get'; Value = 1; Why = 't' } ) }"
        (Invoke-MosTune -Command check).Results[0].Status | Should Be 'unknown'
    }
}
