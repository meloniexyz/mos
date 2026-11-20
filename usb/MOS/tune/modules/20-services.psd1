# Services with no role in running VALORANT, plus telemetry and update-timing policies.
# Core OS, networking, audio, crypto, firewall engine and Windows Update services are on the keep-list.
@{
    Module = 'services'
    Tweaks = @(
        @{ Id = 'svc-search'; Tier = 'standard'; Type = 'Service'; Target = 'WSearch'; Value = 'Disabled'; Why = 'Search indexer re-scans files in the background.' }
        @{ Id = 'svc-print-spooler'; Tier = 'standard'; Type = 'Service'; Target = 'Spooler'; Value = 'Disabled'; Why = 'No printer on MOS.' }
        @{ Id = 'svc-fax'; Tier = 'standard'; Type = 'Service'; Target = 'Fax'; Value = 'Disabled'; Why = 'No fax.' }
        @{ Id = 'svc-telemetry'; Tier = 'standard'; Type = 'Service'; Target = 'DiagTrack'; Value = 'Disabled'; Why = 'Connected User Experiences and Telemetry uploads usage data.' }
        @{ Id = 'svc-wap-push'; Tier = 'standard'; Type = 'Service'; Target = 'dmwappushservice'; Value = 'Disabled'; Why = 'Telemetry message routing.' }
        @{ Id = 'svc-xbox-auth'; Tier = 'standard'; Type = 'Service'; Target = 'XblAuthManager'; Value = 'Disabled'; Why = 'Xbox Live auth, not used by VALORANT.' }
        @{ Id = 'svc-xbox-save'; Tier = 'standard'; Type = 'Service'; Target = 'XblGameSave'; Value = 'Disabled'; Why = 'Xbox cloud saves.' }
        @{ Id = 'svc-xbox-net'; Tier = 'standard'; Type = 'Service'; Target = 'XboxNetApiSvc'; Value = 'Disabled'; Why = 'Xbox networking.' }
        @{ Id = 'svc-xbox-accessories'; Tier = 'standard'; Type = 'Service'; Target = 'XboxGipSvc'; Value = 'Disabled'; Why = 'Xbox accessory management (controller firmware).' }
        @{ Id = 'svc-maps'; Tier = 'standard'; Type = 'Service'; Target = 'MapsBroker'; Value = 'Disabled'; Why = 'Offline map downloads.' }
        @{ Id = 'svc-geolocation'; Tier = 'standard'; Type = 'Service'; Target = 'lfsvc'; Value = 'Disabled'; Why = 'Location service.' }
        @{ Id = 'svc-retail-demo'; Tier = 'standard'; Type = 'Service'; Target = 'RetailDemo'; Value = 'Disabled'; Why = 'Store demo mode.' }
        @{ Id = 'svc-link-tracking'; Tier = 'standard'; Type = 'Service'; Target = 'TrkWks'; Value = 'Disabled'; Why = 'Tracks shortcuts across network drives.' }
        @{ Id = 'svc-parental'; Tier = 'standard'; Type = 'Service'; Target = 'WpcMonSvc'; Value = 'Disabled'; Why = 'Parental controls.' }
        @{ Id = 'svc-payments'; Tier = 'standard'; Type = 'Service'; Target = 'SEMgrSvc'; Value = 'Disabled'; Why = 'NFC payments.' }
        @{ Id = 'svc-insider'; Tier = 'standard'; Type = 'Service'; Target = 'wisvc'; Value = 'Disabled'; Why = 'Windows Insider service.' }
        @{ Id = 'svc-hotspot'; Tier = 'standard'; Type = 'Service'; Target = 'icssvc'; Value = 'Disabled'; Why = 'Mobile hotspot.' }
        @{ Id = 'svc-wallet'; Tier = 'standard'; Type = 'Service'; Target = 'WalletService'; Value = 'Disabled'; Why = 'Wallet.' }
        @{ Id = 'svc-phone'; Tier = 'standard'; Type = 'Service'; Target = 'PhoneSvc'; Value = 'Disabled'; Why = 'Telephony state for Phone Link.' }
        @{ Id = 'svc-connected-devices'; Tier = 'standard'; Type = 'Service'; Target = 'CDPSvc'; Value = 'Disabled'; Why = 'Connected Devices Platform (Phone Link, Nearby Share).' }
        @{ Id = 'svc-compat-assistant'; Tier = 'standard'; Type = 'Service'; Target = 'PcaSvc'; Value = 'Disabled'; Why = 'Program Compatibility Assistant watches every program start.' }
        @{ Id = 'svc-diag-policy'; Tier = 'standard'; Type = 'Service'; Target = 'DPS'; Value = 'Disabled'; Why = 'Diagnostic Policy Service (troubleshooters, resource usage tracking).' }
        @{ Id = 'svc-diag-service-host'; Tier = 'standard'; Type = 'Service'; Target = 'WdiServiceHost'; Value = 'Disabled'; Why = 'Diagnostic host.' }
        @{ Id = 'svc-diag-system-host'; Tier = 'standard'; Type = 'Service'; Target = 'WdiSystemHost'; Value = 'Disabled'; Why = 'Diagnostic host.' }
        @{ Id = 'svc-inventory'; Tier = 'standard'; Type = 'Service'; Target = 'InventorySvc'; Value = 'Disabled'; Why = 'Inventory and compatibility appraisal (newer builds).' }
        @{ Id = 'svc-health-experiences'; Tier = 'standard'; Type = 'Service'; Target = 'whesvc'; Value = 'Disabled'; Why = 'Windows health and optimized experiences.' }
        @{ Id = 'svc-messaging'; Tier = 'standard'; Type = 'Service'; Target = 'MessagingService'; Value = 'Disabled'; Why = 'SMS relay.' }
        @{ Id = 'svc-sync-host'; Tier = 'standard'; Type = 'Service'; Target = 'OneSyncSvc'; Value = 'Disabled'; Why = 'Mail/contacts/calendar sync.' }
        @{ Id = 'svc-net-usage'; Tier = 'standard'; Type = 'Service'; Target = 'Ndu'; Value = 'Disabled'; Why = 'Network data usage monitor driver counts every packet.' }

        # policies: telemetry minimum, updates on your schedule, no peer-to-peer update sharing
        @{ Id = 'policy-telemetry-min'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0; ValueType = 'DWord'; Why = 'Lowest diagnostic data level Pro allows.' }
        @{ Id = 'policy-no-feedback'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Value = 1; ValueType = 'DWord'; Why = 'No feedback pop-ups.' }
        @{ Id = 'policy-wu-notify'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'AUOptions'; Value = 2; ValueType = 'DWord'; Why = 'Windows Update asks before downloading, so it never starts during a match. Run it from Settings yourself.' }
        @{ Id = 'policy-wu-no-auto-reboot'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoRebootWithLoggedOnUsers'; Value = 1; ValueType = 'DWord'; Why = 'No forced restarts while signed in.' }
        @{ Id = 'policy-delivery-opt'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0; ValueType = 'DWord'; Why = 'No uploading updates to other PCs.' }
    )
}
