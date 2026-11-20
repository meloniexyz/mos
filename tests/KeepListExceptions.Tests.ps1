. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

function Write-TestKeepList([string]$Path, [string]$Exceptions) {
    Set-Content -Path $Path -Encoding UTF8 -Value @"
@{
    Services = @('BFE')
    RegistryKeyPatterns = @('HKLM:\SYSTEM\CurrentControlSet\Control\CI*')
    RegistryExceptions = @( $Exceptions )
    RegistryValueNames = @('MitigationOptions')
}
"@
}

Describe 'Keep-list exact-value exceptions (tune-round-2 1.1)' {
    AfterEach { Clear-MosTestEnv }

    It 'allows the excepted value and still rejects its neighbours' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\x1"
        $kl = "$TestDrive\x1\keep.psd1"
        Write-TestKeepList $kl "@{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'VerifiedAndReputablePolicyState' }"
        Set-MosConfig @{ KeepListPath = $kl }
        Write-MosTestModule $m '10-ci' @'
@{ Tweaks = @(
  @{ Id = 'sac'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'VerifiedAndReputablePolicyState'; Value = 0; ValueType = 'DWord'; Why = 't' }
  @{ Id = 'sac-case'; Tier = 'standard'; Type = 'Registry'; Target = 'hklm:\system\currentcontrolset\control\ci\policy'; Name = 'verifiedandreputablepolicystate'; Value = 0; ValueType = 'DWord'; Why = 't' }
  @{ Id = 'neighbour'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'SkuPolicyRequired'; Value = 0; ValueType = 'DWord'; Why = 't' }
  @{ Id = 'subkey'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy\Sub'; Name = 'VerifiedAndReputablePolicyState'; Value = 0; ValueType = 'DWord'; Why = 't' }
) }
'@
        $r = Import-MosTweaks
        ($r.Tweaks | ForEach-Object { $_.Id } | Sort-Object) -join ',' | Should Be 'sac,sac-case'
        ($r.Rejected | ForEach-Object { $_.Id } | Sort-Object) -join ',' | Should Be 'neighbour,subkey'
        $r.Rejected | ForEach-Object { $_.Reason | Should Match 'keep-list' }
    }
    It 'refuses a wildcard exception and loads nothing' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\x2"
        $kl = "$TestDrive\x2\keep.psd1"
        Write-TestKeepList $kl "@{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\*'; Name = 'Anything' }"
        Set-MosConfig @{ KeepListPath = $kl }
        Write-MosTestModule $m '10-x' "@{ Tweaks = @( @{ Id = 'a'; Tier = 'standard'; Type = 'Fake'; Target = 'a'; Value = 1; Why = 't' } ) }"
        { Import-MosTweaks } | Should Throw 'wildcards'
    }
    It 'refuses an exception without Key or Name' {
        $null = Initialize-MosTestEnv -Root "$TestDrive\x3"
        $kl = "$TestDrive\x3\keep.psd1"
        Write-TestKeepList $kl "@{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' }"
        Set-MosConfig @{ KeepListPath = $kl }
        { Import-MosTweaks } | Should Throw 'Key and Name'
    }
    It 'never lets an exception unlock a protected value name' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\x4"
        $kl = "$TestDrive\x4\keep.psd1"
        Write-TestKeepList $kl "@{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'MitigationOptions' }"
        Set-MosConfig @{ KeepListPath = $kl }
        Write-MosTestModule $m '10-m' "@{ Tweaks = @( @{ Id = 'mit'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'MitigationOptions'; Value = 0; ValueType = 'QWord'; Why = 't' } ) }"
        $r = Import-MosTweaks
        @($r.Tweaks).Count | Should Be 0
        $r.Rejected[0].Reason | Should Match "value 'MitigationOptions' is protected"
    }
}

Describe 'Real keep-list exception (tune-round-2 1.2)' {
    It 'contains exactly the Smart App Control value and nothing broader' {
        $k = Import-PowerShellDataFile (Join-Path $script:TuneDir 'keep-list.psd1')
        @($k.RegistryExceptions).Count | Should Be 1
        $k.RegistryExceptions[0].Key | Should Be 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'
        $k.RegistryExceptions[0].Name | Should Be 'VerifiedAndReputablePolicyState'
    }
}
