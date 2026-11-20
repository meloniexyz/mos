# MOS power plan: a copy of High performance with the CPU held at full clocks and nothing going to sleep.
# CPU idle states (C-states) are NOT disabled: boost clocks depend on idle cores, and SMT CPUs lose performance without them.
# GUIDs: SUB_PROCESSOR 54533251..., SUB_VIDEO 7516b95f..., SUB_DISK 0012ee47..., SUB_SLEEP 238c9fa8..., USB 2a737441..., PCIe 501a4d13...
@{
    Module = 'power'
    Tweaks = @(
        @{ Id = 'power-plan'; Tier = 'standard'; Type = 'Script'; Script = 'powerplan'; Why = 'Creates the "MOS" plan (copy of High performance) and makes it active. Undo switches back to the previous plan.' }
        @{ Id = 'power-cpu-min'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '893dee8e-2bef-41e0-89c6-b55d0929964c'; Value = 100; Why = 'Minimum processor state 100%.' }
        @{ Id = 'power-cpu-max'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = 'bc5038f7-23e0-4960-96da-33abaf5935ec'; Value = 100; Why = 'Maximum processor state 100%.' }
        @{ Id = 'power-core-parking-off'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '0cc5b647-c1df-4637-891a-dec35c318583'; Value = 100; Why = 'Core parking minimum cores 100%: no core is parked.' }
        @{ Id = 'power-no-throttle-states'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb'; Value = 0; Why = 'Allow throttle states: off.' }
        @{ Id = 'power-display-never-off'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '7516b95f-f776-4464-8c53-06167f40cc99'; Setting = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'; Value = 0; Why = 'Display never turns off.' }
        @{ Id = 'power-disk-never-off'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '0012ee47-9041-4b5d-9b77-535fba8b1442'; Setting = '6738e2c4-e8a5-4a42-b16a-e040e769756e'; Value = 0; Why = 'Disks never spin down.' }
        @{ Id = 'power-no-sleep'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'; Setting = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'; Value = 0; Why = 'Never sleep.' }
        @{ Id = 'power-no-hibernate-timeout'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '238c9fa8-0aad-41ed-83f4-97be242c8f20'; Setting = '9d7815a6-7ee4-497e-8888-515a05f02364'; Value = 0; Why = 'Never hibernate.' }
        @{ Id = 'power-usb-suspend-off'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '2a737441-1930-4402-8d77-b2bebba308a3'; Setting = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'; Value = 0; Why = 'USB selective suspend off: mouse and keyboard ports never doze.' }
        @{ Id = 'power-pcie-aspm-off'; Tier = 'standard'; Type = 'PowerSetting'; Scheme = 'MOS'; Subgroup = '501a4d13-42af-4429-9fd1-a8218c268e20'; Setting = 'ee12f906-d277-404b-b6da-e5fa1a576df5'; Value = 0; Why = 'PCI Express link power management off (GPU, NIC).' }

        @{ Id = 'boot-no-platform-clock'; Tier = 'standard'; Type = 'Bcd'; Target = 'useplatformclock'; Remove = $true; Why = 'Makes sure the timer is not forced onto HPET (a common "tweak" linked to stutter). Only removes the setting, never adds it.' }
        @{ Id = 'power-hibernation-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'HibernateEnabled'; Value = 0; ValueType = 'DWord'; Why = 'No hibernation file.' }
        @{ Id = 'power-fast-startup-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Value = 0; ValueType = 'DWord'; Why = 'Fast startup off: required for safe dual-booting (each OS sees the others'' drives fully shut down).' }
    )
}
