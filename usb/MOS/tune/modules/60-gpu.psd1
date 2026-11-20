# NVIDIA GPU: message-signaled interrupts, and no NVIDIA App (the driver is installed alone, see INSTALL.md).
@{
    Module = 'gpu'
    Tweaks = @(
        @{ Id = 'gpu-msi-mode'; Tier = 'standard'; Type = 'PnpRegistry'; Class = 'Display'; InstancePattern = 'PCI\VEN_10DE*'
           SubKey = 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'; Name = 'MSISupported'; Value = 1; ValueType = 'DWord'
           Why = 'GPU uses message-signaled interrupts instead of a shared line IRQ: lower interrupt latency. Takes effect after reboot.' }
        @{ Id = 'gpu-no-nvidia-app'; Tier = 'standard'; Type = 'Script'; Script = 'nvidia-app'; Why = 'NVIDIA App and its overlay hook into games and run background services. Runs its uninstaller if present.' }
    )
}
