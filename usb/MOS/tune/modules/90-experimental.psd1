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

        @{ Id = 'exp-mpo-off'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Value = 5; ValueType = 'DWord'; Why = 'Multiplane overlay off. Fixes stutter/flicker on some NVIDIA setups; can hurt windowed flip mode, and some builds ignore it. Reboot needed.' }
        @{ Id = 'exp-priority-separation'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'; Name = 'Win32PrioritySeparation'; Value = 38; ValueType = 'DWord'; Why = 'Scheduler: short, variable time slices with the highest foreground boost (0x26; Windows default is 2). Effect is unproven; keep only on a measured gain.' }
        @{ Id = 'exp-fso-off'; Tier = 'experimental'; Type = 'Script'; Script = 'fso-valorant'; Why = 'Fullscreen optimizations off for the VALORANT executable (AppCompat layer). Riot narrowed the windowed/fullscreen latency gap in 2025, so expect little. Skipped until the game is installed.' }
        @{ Id = 'exp-gpu-irq-policy'; Tier = 'experimental'; Type = 'PnpRegistry'; Class = 'Display'; InstancePattern = 'PCI\VEN_10DE*'
           SubKey = 'Device Parameters\Interrupt Management\Affinity Policy'; Name = 'DevicePolicy'; Value = 4; ValueType = 'DWord'
           Why = 'GPU interrupts go to one chosen processor (IrqPolicySpecifiedProcessors). Use with exp-gpu-irq-mask; bench with -WithCounters. Reboot needed.' }
        @{ Id = 'exp-gpu-irq-mask'; Tier = 'experimental'; Type = 'PnpRegistry'; Class = 'Display'; InstancePattern = 'PCI\VEN_10DE*'
           SubKey = 'Device Parameters\Interrupt Management\Affinity Policy'; Name = 'AssignmentSetOverride'; Value = @(4, 0, 0, 0, 0, 0, 0, 0); ValueType = 'Binary'
           Why = 'The chosen processor: logical CPU 2 (first thread of the second core), away from CPU 0 where most interrupts land.' }

        @{ Id = 'exp-sysmain-off'; Tier = 'experimental'; Type = 'Service'; Target = 'SysMain'; Value = 'Disabled'; Why = 'SysMain (Superfetch) off. Reports of stutter from it are anecdotal; on an SSD with spare RAM the loss is small. Keep only on a measured gain.' }
        @{ Id = 'exp-memory-compression-off'; Tier = 'experimental'; Type = 'Script'; Script = 'memory-compression'; Why = 'Memory compression off (saves the CPU cost of compressing pages; only sensible with plenty of free RAM). Restart needed. Needs admin to read.' }
        @{ Id = 'exp-windowed-optimizations'; Tier = 'experimental'; Type = 'Script'; Script = 'dx-global-setting'; Key = 'SwapEffectUpgradeEnable'; Value = '1'; Why = 'Optimizations for windowed games on (flip-model presentation for DX10/11 in windowed and borderless). Only matters if VALORANT runs windowed or borderless; can cause tearing.' }

        @{ Id = 'exp-defender-quiet'; Tier = 'experimental'; Type = 'Script'; Script = 'defender-quiet'; Why = 'Defender stays on, but skips the Riot folders and keeps scans to idle time at low CPU. Opt-in: excluding folders lowers protection for them.' }

        @{ Id = 'exp-vbs-on-vbs'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Value = 1; ValueType = 'DWord'; Why = 'Only if Riot requires it, or for Vanguard on-demand mode: VBS on.' }
        @{ Id = 'exp-vbs-on-hvci'; Tier = 'experimental'; Type = 'Registry'; Target = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Value = 1; ValueType = 'DWord'; Why = 'Memory integrity on.' }
        @{ Id = 'exp-vbs-on-hypervisor'; Tier = 'experimental'; Type = 'Bcd'; Target = 'hypervisorlaunchtype'; Value = 'Auto'; Why = 'VBS needs the hypervisor to load at boot.' }
    )
}
