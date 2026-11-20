# Things no MOS tweak may change. Riot Vanguard, Windows Update, security and core OS depend on them.
# The tuner rejects any tweak that targets an entry below, even if a module defines it.
@{
    Services = @(
        # firewall engine, crypto, management, update, licensing
        'BFE', 'MpsSvc', 'CryptSvc', 'Winmgmt', 'wuauserv', 'UsoSvc', 'WaaSMedicSvc', 'TrustedInstaller', 'BITS',
        'sppsvc', 'LicenseManager', 'ClipSVC', 'KeyIso', 'VaultSvc', 'SamSs', 'TBS',
        # Defender and security center
        'WinDefend', 'WdNisSvc', 'SecurityHealthService', 'wscsvc',
        # Riot Vanguard
        'vgc', 'vgk',
        # core OS plumbing
        'RpcSs', 'RpcEptMapper', 'DcomLaunch', 'PlugPlay', 'Power', 'EventLog', 'Schedule', 'ProfSvc', 'LSM', 'gpsvc',
        'BrokerInfrastructure', 'SystemEventsBroker', 'TimeBrokerSvc', 'CoreMessagingRegistrar', 'StateRepository',
        'AppXSvc', 'Appinfo', 'UserManager', 'DeviceInstall', 'msiserver', 'TextInputManagementService', 'W32Time',
        # networking
        'Dhcp', 'Dnscache', 'nsi', 'NlaSvc', 'netprofm', 'Wcmsvc', 'WlanSvc', 'LanmanWorkstation',
        # audio, input, display
        'Audiosrv', 'AudioEndpointBuilder', 'hidserv', 'DispBrokerDesktopSvc', 'NVDisplay.ContainerLocalSystem'
    )

    # Registry keys (wildcards) that no Registry tweak may write under.
    RegistryKeyPatterns = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\CI*',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography*',
        'HKLM:\SOFTWARE\Microsoft\Cryptography*',
        'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography*',
        'HKLM:\SOFTWARE\Microsoft\SystemCertificates*',
        'HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates*',
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot*',
        'HKLM:\SOFTWARE\Microsoft\Tpm*',
        'HKLM:\SYSTEM\CurrentControlSet\Services\TPM*',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options*',
        'HKLM:\SOFTWARE\Microsoft\Windows Defender*',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender*',
        'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend*',
        'HKLM:\SYSTEM\CurrentControlSet\Services\vgk*',
        'HKLM:\SYSTEM\CurrentControlSet\Services\vgc*',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa*'
    )

    # Value names that are protected wherever they appear (exploit protections: CFG, DEP, SEHOP, ASLR).
    RegistryValueNames = @('MitigationOptions', 'MitigationAuditOptions', 'DisableExceptionChainValidation', 'MoveImages', 'KernelSEHOPEnabled')

    # Boot configuration settings that stay as Windows set them.
    BcdSettings = @('nx', 'testsigning', 'nointegritychecks', 'debug', 'bootdebug', 'hypervisordebug', 'loadoptions', 'integrityservices')

    # Apps that system components, Defender's UI, the Riot Client or Windows itself need.
    AppxPatterns = @(
        '*WebView*', '*VCLibs*', '*UI.Xaml*', '*NET.Native*', '*WindowsAppRuntime*', '*DesktopAppInstaller*',
        'Microsoft.WindowsStore', '*StorePurchaseApp*', '*SecHealthUI*', '*ShellExperienceHost*',
        '*StartMenuExperienceHost*', '*immersivecontrolpanel*', '*Win32WebViewHost*', '*AAD.BrokerPlugin*'
    )

    OptionalFeatures = @('Windows-Defender-Default-Definitions')

    ScheduledTaskPatterns = @(
        '\Microsoft\Windows\WindowsUpdate\*', '\Microsoft\Windows\UpdateOrchestrator\*', '\Microsoft\Windows\WaaSMedic\*',
        '\Microsoft\Windows\Windows Defender\*', '\Microsoft\Windows\TPM\*', '\Microsoft\Windows\CertificateServicesClient\*',
        '\Microsoft\Windows\SoftwareProtectionPlatform\*', '\Microsoft\Windows\Time Synchronization\*',
        '\Microsoft\Windows\Defrag\*'   # also runs SSD TRIM
    )
}
