. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$regModule = @'
@{ Tweaks = @(
  @{ Id = 'reg-new'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\MOS-test\sub'; Name = 'NewValue'; Value = 1; ValueType = 'DWord'; Why = 't' }
  @{ Id = 'reg-change'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\MOS-test'; Name = 'Existing'; Value = 'mos'; ValueType = 'String'; Why = 't' }
  @{ Id = 'reg-remove'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\MOS-test'; Name = 'Gone'; Remove = $true; Why = 't' }
) }
'@

Describe 'Registry handler (3.1)' {
    BeforeEach {
        Remove-Item 'HKCU:\Software\MOS-test' -Recurse -Force -ErrorAction SilentlyContinue
        New-Item 'HKCU:\Software\MOS-test' -Force | Out-Null
        New-ItemProperty 'HKCU:\Software\MOS-test' -Name Existing -Value 'windows' -PropertyType String | Out-Null
        New-ItemProperty 'HKCU:\Software\MOS-test' -Name Gone -Value 7 -PropertyType DWord | Out-Null
    }
    AfterEach { Remove-Item 'HKCU:\Software\MOS-test' -Recurse -Force -ErrorAction SilentlyContinue; Clear-MosTestEnv }

    It 'reads values and absent values' {
        $null = Initialize-MosTestEnv -Root "$TestDrive\h1"
        $h = Get-MosHandler Registry
        (& $h.Get @{ Target = 'HKCU:\Software\MOS-test'; Name = 'Existing' }).Value | Should Be 'windows'
        (& $h.Get @{ Target = 'HKCU:\Software\MOS-test'; Name = 'Nope' }).Absent | Should Be $true
        (& $h.Get @{ Target = 'HKCU:\Software\MOS-test\none'; Name = 'x' }).Absent | Should Be $true
    }
    It 'applies, checks and undoes a full round trip' {
        $m = Initialize-MosTestEnv -Root "$TestDrive\h2" -AsHost
        Write-MosTestModule $m '10-reg' $regModule
        $run = Invoke-MosTune -Command apply
        @($run.Results | Where-Object Status -eq 'applied').Count | Should Be 3
        (Get-ItemProperty 'HKCU:\Software\MOS-test\sub').NewValue | Should Be 1
        (Get-ItemProperty 'HKCU:\Software\MOS-test').Existing | Should Be 'mos'
        (Get-Item 'HKCU:\Software\MOS-test').GetValueNames() -contains 'Gone' | Should Be $false
        (Invoke-MosTune -Command check).Results | ForEach-Object { $_.Status | Should Be 'ok' }

        $null = Invoke-MosTune -Command undo
        (Get-Item 'HKCU:\Software\MOS-test\sub').GetValueNames() -contains 'NewValue' | Should Be $false
        (Get-ItemProperty 'HKCU:\Software\MOS-test').Existing | Should Be 'windows'
        (Get-ItemProperty 'HKCU:\Software\MOS-test').Gone | Should Be 7
        (Get-Item 'HKCU:\Software\MOS-test').GetValueKind('Gone') | Should Be 'DWord'
    }
}

Describe 'IniFile handler (3.2)' {
    AfterEach { Clear-MosTestEnv }

    $sample = @"
[/Script/ShooterGame.ShooterGameUserSettings]
ResolutionSizeX=1920
bUseVSync=False

[ScalabilityGroups]
sg.ShadowQuality=3
sg.TextureQuality=1
sg.EffectsQuality=3

[/Script/Engine.GameUserSettings]
bUseDesiredScreenHeight=False
"@

    It 'sets keys in the section, keeps other sections, backs up and undoes' {
        $root = "$TestDrive\ini1"
        $m = Initialize-MosTestEnv -Root $root -AsHost
        $cfg = "$root\VALORANT\Saved\Config"
        New-Item -ItemType Directory -Force "$cfg\acct-eu\WindowsClient", "$cfg\_backup_x\WindowsClient" | Out-Null
        [IO.File]::WriteAllText("$cfg\acct-eu\WindowsClient\GameUserSettings.ini", $sample.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n")
        [IO.File]::WriteAllText("$cfg\_backup_x\WindowsClient\GameUserSettings.ini", $sample)
        $path = ($cfg + '\*\WindowsClient\GameUserSettings.ini').Replace("'", "''")
        Write-MosTestModule $m '10-ini' @"
@{ Tweaks = @( @{ Id = 'ini-low'; Tier = 'standard'; Type = 'IniFile'; Path = '$path'; Exclude = @('*\_backup*'); Section = 'ScalabilityGroups'
   Settings = @{ 'sg.ShadowQuality' = '0'; 'sg.TextureQuality' = '0'; 'sg.FoliageQuality' = '0' }; Why = 't' } ) }
"@
        $file = "$cfg\acct-eu\WindowsClient\GameUserSettings.ini"
        $run = Invoke-MosTune -Command apply
        $run.Results[0].Status | Should Be 'applied'
        $text = [IO.File]::ReadAllText($file)
        $text | Should Match 'sg\.ShadowQuality=0'
        $text | Should Match 'sg\.TextureQuality=0'
        $text | Should Match 'sg\.FoliageQuality=0'
        $text | Should Match 'sg\.EffectsQuality=3'
        $text | Should Match '\[/Script/Engine\.GameUserSettings\]\r\nbUseDesiredScreenHeight=False\r\n$'
        Test-Path "$file.mos-backup" | Should Be $true
        [IO.File]::ReadAllText("$cfg\_backup_x\WindowsClient\GameUserSettings.ini") | Should Match 'sg\.ShadowQuality=3'

        $null = Invoke-MosTune -Command undo
        $text = [IO.File]::ReadAllText($file)
        $text | Should Match 'sg\.ShadowQuality=3'
        $text | Should Match 'sg\.TextureQuality=1'
        $text | Should Not Match 'FoliageQuality'
    }
    It 'skips with a hint when no settings file exists yet' {
        $root = "$TestDrive\ini2"
        $m = Initialize-MosTestEnv -Root $root -AsHost
        Write-MosTestModule $m '10-ini' @"
@{ Tweaks = @( @{ Id = 'ini-low'; Tier = 'standard'; Type = 'IniFile'; Path = '$root\nothing\*.ini'; Section = 'S'; Settings = @{ a = '1' }; Why = 't' } ) }
"@
        $r = (Invoke-MosTune -Command apply).Results[0]
        $r.Status | Should Be 'skipped'
        $r.Detail | Should Match 'launch the game once'
    }
}
