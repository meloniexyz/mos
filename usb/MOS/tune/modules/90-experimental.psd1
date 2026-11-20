# Experimental: never applied by default. Apply one group by id, benchmark, keep only if it wins.
#   .\tune.ps1 apply -Id exp-spectre-*     then reboot, bench, compare
#   .\tune.ps1 undo  -Id exp-spectre-*     if it did not help
# None of these touch CFG, DEP or other exploit protections (the keep-list blocks that).
@{
    Module = 'experimental'
    Tweaks = @(
        @{ Id = 'exp-spectre-override'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'FeatureSettingsOverride'; Value = 3; ValueType = 'DWord'; Why = 'Turns off the Spectre v2 / Meltdown kernel mitigations only. Can help older CPUs. Reboot needed.' }
        @{ Id = 'exp-spectre-mask'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'FeatureSettingsOverrideMask'; Value = 3; ValueType = 'DWord'; Why = 'Mask that goes with FeatureSettingsOverride.' }

        @{ Id = 'exp-hags-off'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Value = 1; ValueType = 'DWord'; Why = 'Hardware-accelerated GPU scheduling off (Windows 11 default is on). Results vary per game and driver. Reboot needed.' }

        @{ Id = 'exp-timer-global'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'; Name = 'GlobalTimerResolutionRequests'; Value = 1; ValueType = 'DWord'; Why = 'Lets one process raise the timer resolution for the whole system (Windows 11 ignores it otherwise). Reboot needed.' }
        @{ Id = 'exp-timer-task'; Tier = 'experimental'; Type = 'Script'; Script = 'timer-task'; Why = 'Logon task that holds a 0.5 ms timer resolution. Use together with exp-timer-global.' }

        @{ Id = 'exp-defender-quiet'; Tier = 'experimental'; Type = 'Script'; Script = 'defender-quiet'; Why = 'Defender stays on, but skips the Riot folders and keeps scans to idle time at low CPU. Opt-in: excluding folders lowers protection for them.' }

        @{ Id = 'exp-vbs-on-vbs'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Value = 1; ValueType = 'DWord'; Why = 'Only if Riot requires it, or for Vanguard on-demand mode: VBS on.' }
        @{ Id = 'exp-vbs-on-hvci'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Value = 1; ValueType = 'DWord'; Why = 'Memory integrity on.' }
        @{ Id = 'exp-vbs-on-hypervisor'; Tier = 'experimental'; Type = 'Bcd'; Target = 'hypervisorlaunchtype'; Value = 'Auto'; Why = 'VBS needs the hypervisor to load at boot.' }
    )
}
