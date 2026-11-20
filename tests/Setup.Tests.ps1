. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'autounattend.xml audit (6.1)' {
    $path = Join-Path $script:RepoRoot 'usb\autounattend.xml'
    [xml]$xml = Get-Content $path -Raw
    $ns = New-Object Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
    $raw = Get-Content $path -Raw

    It 'is valid XML with the unattend root' { $xml.DocumentElement.LocalName | Should Be 'unattend' }
    It 'keeps time zone and keyboard as placeholders (no personal settings in the repo)' {
        $xml.SelectSingleNode('//u:TimeZone', $ns).InnerText | Should Be '__TIMEZONE__'
        $xml.SelectNodes('//u:InputLocale', $ns) | ForEach-Object { $_.InnerText | Should Be '__INPUTLOCALE__' }
    }
    It 'never configures, wipes or picks a disk' {
        foreach ($e in 'DiskConfiguration', 'WillWipeDisk', 'InstallTo', 'InstallToAvailablePartition', 'ImageInstall', 'CreatePartitions', 'ModifyPartitions') {
            $xml.SelectNodes("//u:$e", $ns).Count | Should Be 0
        }
    }
    It 'uses the generic Windows 11 Pro setup key' {
        $xml.SelectSingleNode('//u:ProductKey/u:Key', $ns).InnerText | Should Be 'VK7JG-NPHTM-C97JM-9MPGT-3V66T'
    }
    It 'creates the local admin account mos and auto-logs on' {
        $acct = $xml.SelectSingleNode('//u:LocalAccount[u:Name="mos"]', $ns)
        $acct | Should Not BeNullOrEmpty
        $acct.Group | Should Be 'Administrators'
        $xml.SelectSingleNode('//u:AutoLogon/u:Enabled', $ns).InnerText | Should Be 'true'
        $xml.SelectSingleNode('//u:AutoLogon/u:Username', $ns).InnerText | Should Be 'mos'
    }
    It 'skips the online account and OOBE screens and names the PC MOS' {
        $xml.SelectSingleNode('//u:OOBE/u:HideOnlineAccountScreens', $ns).InnerText | Should Be 'true'
        $xml.SelectSingleNode('//u:OOBE/u:ProtectYourPC', $ns).InnerText | Should Be '3'
        $xml.SelectSingleNode('//u:ComputerName', $ns).InnerText | Should Be 'MOS'
    }
    It 'runs the bootstrap from the USB marker on first logon, never from C:' {
        $cmd = $xml.SelectSingleNode('//u:FirstLogonCommands/u:SynchronousCommand/u:CommandLine', $ns).InnerText
        $cmd | Should Match 'MOS\\mos\.usb'
        $cmd | Should Match 'MOS\\bootstrap\.ps1'
        $cmd | Should Not Match 'in \(C '
    }
}

Describe 'prep-usb.ps1 (6.2)' {
    . (Join-Path $script:RepoRoot 'windows10\prep-usb.ps1')

    It 'parses the boot entry identifier from bcdedit /v output' {
        $sample = @('Windows Boot Loader', '-------------------', 'identifier              {1a2b3c4d-1111-2222-3333-444455556666}', 'device                  partition=C:')
        Get-BcdCurrentIdentifier $sample | Should Be '{1a2b3c4d-1111-2222-3333-444455556666}'
        Get-BcdCurrentIdentifier @('nothing here') | Should BeNullOrEmpty
    }
    It 'builds the stick layout in a stand-in folder' {
        $Target = Join-Path $TestDrive 'stick'
        New-Item -ItemType Directory $Target | Out-Null
        $MainGuid = '{1a2b3c4d-1111-2222-3333-444455556666}'
        $SkipMediaCheck = $true
        $TimeZone = 'W. Europe Standard Time'; $InputLocale = '0407:00000407;0409:00000409'
        $r = Invoke-PrepUsb 6>$null
        Test-Path (Join-Path $Target 'autounattend.xml') | Should Be $true
        [xml]$stick = Get-Content (Join-Path $Target 'autounattend.xml') -Raw
        $raw = $stick.OuterXml
        $raw | Should Not Match '__TIMEZONE__|__INPUTLOCALE__'
        $raw | Should Match '<TimeZone>W\. Europe Standard Time</TimeZone>'
        $raw | Should Match '<InputLocale>0407:00000407;0409:00000409</InputLocale>'
        Test-Path (Join-Path $Target 'MOS\mos.usb') | Should Be $true
        Test-Path (Join-Path $Target 'MOS\bootstrap.ps1') | Should Be $true
        Test-Path (Join-Path $Target 'MOS\tune\tune.ps1') | Should Be $true
        (Get-Content (Join-Path $Target 'MOS\boot\main.guid')).Trim() | Should Be $MainGuid
    }
    It 'reads this Windows'' keyboard layouts in answer-file form and rejects odd values' {
        Get-CurrentInputLocale | Should Match '^[0-9a-f]{4}:[0-9a-f]{8}(;[0-9a-f]{4}:[0-9a-f]{8})*$'
        { New-AnswerFileText 'x' 'Bad<Zone' '0409:00000409' } | Should Throw 'time zone'
        { New-AnswerFileText 'x' 'UTC' '<x>' } | Should Throw 'input locale'
    }
    It 'refuses a folder that is not setup media' {
        $Target = Join-Path $TestDrive 'not-media'
        New-Item -ItemType Directory $Target | Out-Null
        $MainGuid = '{1a2b3c4d-1111-2222-3333-444455556666}'
        $SkipMediaCheck = $false
        { Invoke-PrepUsb } | Should Throw 'not Windows setup media'
    }
    It 'refuses the system drive' {
        $Target = "$env:SystemDrive\"
        $MainGuid = '{1a2b3c4d-1111-2222-3333-444455556666}'
        $SkipMediaCheck = $true
        { Invoke-PrepUsb } | Should Throw 'system drive'
    }
}

Describe 'bootstrap.ps1 (6.3)' {
    . (Join-Path $script:RepoRoot 'usb\MOS\bootstrap.ps1')

    It 'finds the USB by its marker on any drive root, never the system drive' {
        $a = Join-Path $TestDrive 'a\'; $b = Join-Path $TestDrive 'b\'
        New-Item -ItemType Directory (Join-Path $a 'other'), (Join-Path $b 'MOS') -Force | Out-Null
        Set-Content (Join-Path $b 'MOS\mos.usb') 'x'
        Find-MosUsb @($a, $b) | Should Be $b
        Find-MosUsb @($a) | Should BeNullOrEmpty
        Find-MosUsb @("$env:SystemDrive\") | Should BeNullOrEmpty
    }
    It 'leaves a desktop note and changes nothing when the USB is missing' {
        $DriveRoots = @((Join-Path $TestDrive 'empty\'))
        New-Item -ItemType Directory $DriveRoots[0] -Force | Out-Null
        $Destination = Join-Path $TestDrive 'dest'
        $DesktopPath = Join-Path $TestDrive 'desktop'
        Invoke-MosBootstrap 3>$null | Should Be 'no-usb'
        Test-Path (Join-Path $DesktopPath 'MOS setup NOT finished.txt') | Should Be $true
        (Get-Content (Join-Path $DesktopPath 'MOS setup NOT finished.txt') -Raw) | Should Match 'bootstrap\.ps1'
        Test-Path $Destination | Should Be $false
    }
    It 'stops when it already finished' {
        $Destination = Join-Path $TestDrive 'done'
        New-Item -ItemType Directory $Destination -Force | Out-Null
        Set-Content (Join-Path $Destination '.bootstrap-done') 'x'
        Invoke-MosBootstrap 6>$null | Should Be 'already-done'
    }
}
