# Power-saving features on the wired adapter (Realtek and Intel keywords). Adapters without a keyword are skipped.
# TCP/IP stack globals are deliberately left at Windows defaults.
@{
    Module = 'network'
    Tweaks = @(
        @{ Id = 'nic-eee-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = '*EEE'; Value = '0'; Why = 'Energy-Efficient Ethernet off: no link sleep between packets.' }
        @{ Id = 'nic-advanced-eee-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'AdvancedEEE'; Value = '0'; Why = 'Realtek Advanced EEE off.' }
        @{ Id = 'nic-green-ethernet-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'EnableGreenEthernet'; Value = '0'; Why = 'Realtek Green Ethernet off.' }
        @{ Id = 'nic-power-saving-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'PowerSavingMode'; Value = '0'; Why = 'Realtek power saving mode off.' }
        @{ Id = 'nic-gigabit-lite-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'GigaLite'; Value = '0'; Why = 'Realtek Gigabit Lite (500 Mbps power mode) off.' }
        @{ Id = 'nic-auto-disable-gigabit-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'AutoDisableGigabit'; Value = '0'; Why = 'Never drops to 100 Mbps to save power.' }
        @{ Id = 'nic-intel-eee-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'EEELinkAdvertisement'; Value = '0'; Why = 'Intel EEE advertisement off.' }
        @{ Id = 'nic-intel-reduce-speed-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'ReduceSpeedOnPowerDown'; Value = '0'; Why = 'Intel: keep link speed.' }
        @{ Id = 'nic-intel-ulp-off'; Tier = 'standard'; Type = 'NetAdapterProperty'; Target = 'ULPMode'; Value = '0'; Why = 'Intel ultra low power mode off.' }
    )
}
