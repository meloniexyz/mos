# No hypervisor under Windows: Hyper-V, VM Platform, Sandbox, Application Guard off, and VBS/HVCI (memory integrity) off.
# Riot Vanguard then runs in its classic always-on mode. If Riot ever requires HVCI, apply the experimental 'exp-vbs-on-*' tweaks.
@{
    Module = 'virtualization'
    Tweaks = @(
        @{ Id = 'feature-hyperv-off'; Tier = 'standard'; Type = 'OptionalFeature'; Target = 'Microsoft-Hyper-V-All'; Value = 'Disabled'; Why = 'Hyper-V puts Windows itself inside a virtual machine.' }
        @{ Id = 'feature-vm-platform-off'; Tier = 'standard'; Type = 'OptionalFeature'; Target = 'VirtualMachinePlatform'; Value = 'Disabled'; Why = 'VM platform (WSL2/Android) starts the hypervisor.' }
        @{ Id = 'feature-sandbox-off'; Tier = 'standard'; Type = 'OptionalFeature'; Target = 'Containers-DisposableClientVM'; Value = 'Disabled'; Why = 'Windows Sandbox starts the hypervisor.' }
        @{ Id = 'feature-app-guard-off'; Tier = 'standard'; Type = 'OptionalFeature'; Target = 'Windows-Defender-ApplicationGuard'; Value = 'Disabled'; Why = 'Application Guard starts the hypervisor (removed on newer builds).' }
        @{ Id = 'boot-hypervisor-off'; Tier = 'standard'; Type = 'Bcd'; Target = 'hypervisorlaunchtype'; Value = 'Off'; Why = 'The hypervisor never loads at boot.' }
        @{ Id = 'vbs-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Value = 0; ValueType = 'DWord'; Why = 'Virtualization-based security off (Windows 11 turns it on by default).' }
        @{ Id = 'hvci-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Value = 0; ValueType = 'DWord'; Why = 'Memory integrity off: removes its per-driver-call overhead.' }
    )
}
