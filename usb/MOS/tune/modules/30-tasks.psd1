# Scheduled tasks that wake the CPU for telemetry, compatibility appraisal and app maintenance.
# Tasks missing on a build are treated as already off. Update, Defender, TPM, certificate, licensing, time and
# disk-optimize (SSD TRIM) tasks are on the keep-list.
@{
    Module = 'tasks'
    Tweaks = @(
        @{ Id = 'task-compat-appraiser'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'; Value = 'Disabled'; Why = 'Scans installed programs for telemetry; heavy CPU burst.' }
        @{ Id = 'task-compat-appraiser-exp'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp'; Value = 'Disabled'; Why = 'Newer variant of the appraiser.' }
        @{ Id = 'task-program-data-updater'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\ProgramDataUpdater'; Value = 'Disabled'; Why = 'Program telemetry.' }
        @{ Id = 'task-startup-app'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\StartupAppTask'; Value = 'Disabled'; Why = 'Rescans startup apps.' }
        @{ Id = 'task-pca-patch'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\PcaPatchDbTask'; Value = 'Disabled'; Why = 'Compatibility assistant database update.' }
        @{ Id = 'task-mare-backup'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Application Experience\MareBackup'; Value = 'Disabled'; Why = 'Compatibility telemetry backup.' }
        @{ Id = 'task-ceip-consolidator'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; Value = 'Disabled'; Why = 'Customer experience program upload.' }
        @{ Id = 'task-ceip-usb'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'; Value = 'Disabled'; Why = 'USB telemetry.' }
        @{ Id = 'task-autochk-proxy'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Autochk\Proxy'; Value = 'Disabled'; Why = 'Disk-check telemetry.' }
        @{ Id = 'task-disk-diag'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'; Value = 'Disabled'; Why = 'Disk diagnostic telemetry.' }
        @{ Id = 'task-feedback-dm'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Feedback\Siuf\DmClient'; Value = 'Disabled'; Why = 'Feedback telemetry.' }
        @{ Id = 'task-feedback-dm-scenario'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'; Value = 'Disabled'; Why = 'Feedback telemetry.' }
        @{ Id = 'task-wer-queue'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Windows Error Reporting\QueueReporting'; Value = 'Disabled'; Why = 'Uploads queued crash reports.' }
        @{ Id = 'task-maps-update'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Maps\MapsUpdateTask'; Value = 'Disabled'; Why = 'Map updates.' }
        @{ Id = 'task-maps-toast'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Maps\MapsToastTask'; Value = 'Disabled'; Why = 'Map notifications.' }
        @{ Id = 'task-cloud-experience'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask'; Value = 'Disabled'; Why = 'Account/OOBE cloud prompts.' }
        @{ Id = 'task-power-diag'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem'; Value = 'Disabled'; Why = 'Power efficiency analysis run.' }
        @{ Id = 'task-winsat'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Maintenance\WinSAT'; Value = 'Disabled'; Why = 'System assessment benchmark.' }
        @{ Id = 'task-family-safety'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Shell\FamilySafetyMonitor'; Value = 'Disabled'; Why = 'Family safety monitoring.' }
        @{ Id = 'task-family-safety-refresh'; Tier = 'standard'; Type = 'ScheduledTask'; Target = '\Microsoft\Windows\Shell\FamilySafetyRefreshTask'; Value = 'Disabled'; Why = 'Family safety refresh.' }
    )
}
