# MOS tweaks

Generated from `usb/MOS/tune/modules` by `tools/gen-tweaks-doc.ps1`. Do not edit the tables by hand, except the "Bench result" column of the experimental table.

- **Apply** the standard profile: `C:\MOS\tune\tune.ps1 apply` (admin, MOS only).
- **Undo** anything: `tune.ps1 undo -Id <id>`, `tune.ps1 undo -Module <module>`, or `tune.ps1 undo` for everything. Each tweak restores the exact value it found.
- **Check** after Windows updates: `tune.ps1 check` lists what drifted.
- Apps are removed for the MOS user only; undo re-registers them. OneDrive undo reinstalls it with the setup in Windows. The NVIDIA App cannot be restored by undo (reinstall from nvidia.com).

166 tweaks: 149 standard, 17 experimental.

## apps

| Id | Changes | Why |
|----|---------|-----|
| `app-bing-news` | app `Microsoft.BingNews` removed | News app, background refresh. |
| `app-bing-weather` | app `Microsoft.BingWeather` removed | Weather app, background refresh. |
| `app-bing-search` | app `Microsoft.BingSearch` removed | Bing search app. |
| `app-get-help` | app `Microsoft.GetHelp` removed | Not used on a game-only install. |
| `app-tips` | app `Microsoft.Getstarted` removed | Tips app and its notifications. |
| `app-office-hub` | app `Microsoft.MicrosoftOfficeHub` removed | Microsoft 365 promo app. |
| `app-solitaire` | app `Microsoft.MicrosoftSolitaireCollection` removed | Bundled game with ads. |
| `app-sticky-notes` | app `Microsoft.MicrosoftStickyNotes` removed | Syncs in the background. |
| `app-people` | app `Microsoft.People` removed | Contacts sync. |
| `app-power-automate` | app `Microsoft.PowerAutomateDesktop` removed | Not used. |
| `app-todo` | app `Microsoft.Todos` removed | Syncs in the background. |
| `app-alarms` | app `Microsoft.WindowsAlarms` removed | Not used. |
| `app-mail` | app `microsoft.windowscommunicationsapps` removed | Mail/Calendar sync. |
| `app-outlook` | app `Microsoft.OutlookForWindows` removed | New Outlook, background sync. |
| `app-feedback-hub` | app `Microsoft.WindowsFeedbackHub` removed | Telemetry prompts. |
| `app-maps` | app `Microsoft.WindowsMaps` removed | Map downloads in the background. |
| `app-sound-recorder` | app `Microsoft.WindowsSoundRecorder` removed | Not used. |
| `app-phone-link` | app `Microsoft.YourPhone` removed | Phone Link keeps a background connection. |
| `app-cross-device` | app `MicrosoftWindows.CrossDevice` removed | Cross-device experience host. |
| `app-media-player` | app `Microsoft.ZuneMusic` removed | Media Player, indexes the music library. |
| `app-movies` | app `Microsoft.ZuneVideo` removed | Not used. |
| `app-clipchamp` | app `Clipchamp.Clipchamp` removed | Video editor promo. |
| `app-quick-assist` | app `MicrosoftCorporationII.QuickAssist` removed | Remote help, not needed. |
| `app-family` | app `MicrosoftCorporationII.MicrosoftFamily` removed | Family safety app. |
| `app-teams` | app `MSTeams` removed | Teams starts with Windows. |
| `app-copilot` | app `Microsoft.Copilot` removed | Copilot app. |
| `app-cortana` | app `Microsoft.549981C3F5F10` removed | Cortana (older builds). |
| `app-devhome` | app `Microsoft.Windows.DevHome` removed | Dev Home, not needed. |
| `app-widgets` | app `MicrosoftWindows.Client.WebExperience` removed | Widgets board and its web host. |
| `app-xbox` | app `Microsoft.GamingApp` removed | Xbox app; VALORANT does not use it. |
| `app-xbox-legacy` | app `Microsoft.XboxApp` removed | Old Xbox Console Companion. |
| `app-game-bar` | app `Microsoft.XboxGamingOverlay` removed | Game Bar overlay hooks into games. |
| `app-xbox-speech` | app `Microsoft.XboxSpeechToTextOverlay` removed | Xbox overlay component. |
| `app-xbox-tcui` | app `Microsoft.Xbox.TCUI` removed | Xbox overlay component. |
| `app-xbox-identity` | app `Microsoft.XboxIdentityProvider` removed | Xbox sign-in, not used. |
| `app-onedrive` | script `onedrive.ps1` | OneDrive syncs and scans files in the background. Undo reinstalls it with the setup that ships in Windows. |
| `edge-no-startup-boost` | `HKLM:\SOFTWARE\Policies\Microsoft\Edge\StartupBoostEnabled` = 0 | Stops Edge preloading at logon. |
| `edge-no-background` | `HKLM:\SOFTWARE\Policies\Microsoft\Edge\BackgroundModeEnabled` = 0 | Edge exits when its window closes. |
| `edge-update-svc` | service `edgeupdate` -> Manual | Edge updater runs only when needed. |
| `edge-update-svc-m` | service `edgeupdatem` -> Manual | Edge updater runs only when needed. |
| `policy-no-copilot` | `HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot` = 1 | Turns off Windows Copilot. |
| `policy-no-recall` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI\DisableAIDataAnalysis` = 1 | Recall snapshots off. |
| `feature-recall` | feature `Recall` -> Disabled | Recall component off (skipped where it does not exist). |
| `policy-no-click-to-do` | `HKCU:\Software\Policies\Microsoft\Windows\WindowsAI\DisableClickToDo` = 1 | Click to Do (on-screen AI actions) off. |
| `policy-no-spotlight` | `HKCU:\Software\Policies\Microsoft\Windows\CloudContent\DisableWindowsSpotlightFeatures` = 1 | Windows Spotlight off: no background downloads of lock-screen and desktop content. |
| `policy-no-widgets` | `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests` = 0 | Widgets board off. |
| `policy-no-consumer-apps` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures` = 1 | Stops Windows from installing suggested apps. |
| `no-silent-app-installs` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled` = 0 | No sponsored app installs. |
| `no-start-suggestions` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SystemPaneSuggestionsEnabled` = 0 | No Start menu suggestions. |
| `no-web-search` | `HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions` = 1 | Start search stays local, no Bing calls. |
| `no-background-apps` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground` = 2 | Store apps cannot run in the background. The Riot Client is a desktop app and is not affected. |

## services

| Id | Changes | Why |
|----|---------|-----|
| `svc-search` | service `WSearch` -> Disabled | Search indexer re-scans files in the background. |
| `svc-print-spooler` | service `Spooler` -> Disabled | No printer on MOS. |
| `svc-fax` | service `Fax` -> Disabled | No fax. |
| `svc-telemetry` | service `DiagTrack` -> Disabled | Connected User Experiences and Telemetry uploads usage data. |
| `svc-wap-push` | service `dmwappushservice` -> Disabled | Telemetry message routing. |
| `svc-xbox-auth` | service `XblAuthManager` -> Disabled | Xbox Live auth, not used by VALORANT. |
| `svc-xbox-save` | service `XblGameSave` -> Disabled | Xbox cloud saves. |
| `svc-xbox-net` | service `XboxNetApiSvc` -> Disabled | Xbox networking. |
| `svc-xbox-accessories` | service `XboxGipSvc` -> Disabled | Xbox accessory management (controller firmware). |
| `svc-maps` | service `MapsBroker` -> Disabled | Offline map downloads. |
| `svc-geolocation` | service `lfsvc` -> Disabled | Location service. |
| `svc-retail-demo` | service `RetailDemo` -> Disabled | Store demo mode. |
| `svc-link-tracking` | service `TrkWks` -> Disabled | Tracks shortcuts across network drives. |
| `svc-parental` | service `WpcMonSvc` -> Disabled | Parental controls. |
| `svc-payments` | service `SEMgrSvc` -> Disabled | NFC payments. |
| `svc-insider` | service `wisvc` -> Disabled | Windows Insider service. |
| `svc-hotspot` | service `icssvc` -> Disabled | Mobile hotspot. |
| `svc-wallet` | service `WalletService` -> Disabled | Wallet. |
| `svc-phone` | service `PhoneSvc` -> Disabled | Telephony state for Phone Link. |
| `svc-connected-devices` | service `CDPSvc` -> Disabled | Connected Devices Platform (Phone Link, Nearby Share). |
| `svc-compat-assistant` | service `PcaSvc` -> Disabled | Program Compatibility Assistant watches every program start. |
| `svc-diag-policy` | service `DPS` -> Disabled | Diagnostic Policy Service (troubleshooters, resource usage tracking). |
| `svc-diag-service-host` | service `WdiServiceHost` -> Disabled | Diagnostic host. |
| `svc-diag-system-host` | service `WdiSystemHost` -> Disabled | Diagnostic host. |
| `svc-inventory` | service `InventorySvc` -> Disabled | Inventory and compatibility appraisal (newer builds). |
| `svc-health-experiences` | service `whesvc` -> Disabled | Windows health and optimized experiences. |
| `svc-messaging` | service `MessagingService` -> Disabled | SMS relay. |
| `svc-sync-host` | service `OneSyncSvc` -> Disabled | Mail/contacts/calendar sync. |
| `svc-net-usage` | service `Ndu` -> Disabled | Network data usage monitor driver counts every packet. |
| `svc-ai-fabric` | service `WSAIFabricSvc` -> Disabled | Windows AI Fabric service (Recall / Click to Do / Live Captions backend on newer builds); users report constant CPU/NPU use and GBs of RAM. It may re-enable itself after updates: check shows that as drift. |
| `sac-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState` = 0 | Smart App Control off (it checks every program and script launch, and once On it would block MOS's unsigned scripts). Driver signing and the rest of code integrity are untouched. Reboot needed. On Windows builds older than the 2026 servicing update, Windows may not let undo turn it back on. |
| `policy-telemetry-min` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry` = 0 | Lowest diagnostic data level Pro allows. |
| `policy-no-feedback` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\DoNotShowFeedbackNotifications` = 1 | No feedback pop-ups. |
| `policy-wu-notify` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\AUOptions` = 2 | Windows Update asks before downloading, so it never starts during a match. Run it from Settings yourself. |
| `policy-wu-no-auto-reboot` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoRebootWithLoggedOnUsers` = 1 | No forced restarts while signed in. |
| `policy-delivery-opt` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization\DODownloadMode` = 0 | No uploading updates to other PCs. |

## tasks

| Id | Changes | Why |
|----|---------|-----|
| `task-compat-appraiser` | task `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser` -> Disabled | Scans installed programs for telemetry; heavy CPU burst. |
| `task-compat-appraiser-exp` | task `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp` -> Disabled | Newer variant of the appraiser. |
| `task-program-data-updater` | task `\Microsoft\Windows\Application Experience\ProgramDataUpdater` -> Disabled | Program telemetry. |
| `task-startup-app` | task `\Microsoft\Windows\Application Experience\StartupAppTask` -> Disabled | Rescans startup apps. |
| `task-pca-patch` | task `\Microsoft\Windows\Application Experience\PcaPatchDbTask` -> Disabled | Compatibility assistant database update. |
| `task-mare-backup` | task `\Microsoft\Windows\Application Experience\MareBackup` -> Disabled | Compatibility telemetry backup. |
| `task-ceip-consolidator` | task `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator` -> Disabled | Customer experience program upload. |
| `task-ceip-usb` | task `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip` -> Disabled | USB telemetry. |
| `task-autochk-proxy` | task `\Microsoft\Windows\Autochk\Proxy` -> Disabled | Disk-check telemetry. |
| `task-disk-diag` | task `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector` -> Disabled | Disk diagnostic telemetry. |
| `task-feedback-dm` | task `\Microsoft\Windows\Feedback\Siuf\DmClient` -> Disabled | Feedback telemetry. |
| `task-feedback-dm-scenario` | task `\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload` -> Disabled | Feedback telemetry. |
| `task-wer-queue` | task `\Microsoft\Windows\Windows Error Reporting\QueueReporting` -> Disabled | Uploads queued crash reports. |
| `task-maps-update` | task `\Microsoft\Windows\Maps\MapsUpdateTask` -> Disabled | Map updates. |
| `task-maps-toast` | task `\Microsoft\Windows\Maps\MapsToastTask` -> Disabled | Map notifications. |
| `task-cloud-experience` | task `\Microsoft\Windows\CloudExperienceHost\CreateObjectTask` -> Disabled | Account/OOBE cloud prompts. |
| `task-power-diag` | task `\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem` -> Disabled | Power efficiency analysis run. |
| `task-winsat` | task `\Microsoft\Windows\Maintenance\WinSAT` -> Disabled | System assessment benchmark. |
| `task-family-safety` | task `\Microsoft\Windows\Shell\FamilySafetyMonitor` -> Disabled | Family safety monitoring. |
| `task-family-safety-refresh` | task `\Microsoft\Windows\Shell\FamilySafetyRefreshTask` -> Disabled | Family safety refresh. |

## power

| Id | Changes | Why |
|----|---------|-----|
| `power-plan` | script `powerplan.ps1` | Creates the "MOS" plan (copy of High performance) and makes it active. Undo switches back to the previous plan. |
| `power-cpu-min` | MOS plan setting `893dee8e-2bef-41e0-89c6-b55d0929964c` = 100 | Minimum processor state 100%. |
| `power-cpu-max` | MOS plan setting `bc5038f7-23e0-4960-96da-33abaf5935ec` = 100 | Maximum processor state 100%. |
| `power-core-parking-off` | MOS plan setting `0cc5b647-c1df-4637-891a-dec35c318583` = 100 | Core parking minimum cores 100%: no core is parked. |
| `power-epp-performance` | MOS plan setting `36687f9e-e3a5-4dbf-b1dc-15eb381c6863` = 0 | Processor energy-performance preference 0 (performance first) for CPUs with CPPC. High performance already uses 0; this keeps it if the plan had to be copied from Balanced. |
| `power-boost-aggressive` | MOS plan setting `be337238-0d82-4146-a960-4f3749d470c7` = 2 | Processor boost mode Aggressive (same reason as above). |
| `power-no-throttle-states` | MOS plan setting `3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb` = 0 | Allow throttle states: off. |
| `power-display-never-off` | MOS plan setting `3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e` = 0 | Display never turns off. |
| `power-disk-never-off` | MOS plan setting `6738e2c4-e8a5-4a42-b16a-e040e769756e` = 0 | Disks never spin down. |
| `power-no-sleep` | MOS plan setting `29f6c1db-86da-48c5-9fdb-f2b67b1f44da` = 0 | Never sleep. |
| `power-no-hibernate-timeout` | MOS plan setting `9d7815a6-7ee4-497e-8888-515a05f02364` = 0 | Never hibernate. |
| `power-usb-suspend-off` | MOS plan setting `48e6b7a6-50f5-4782-a5d4-53bb8f07e226` = 0 | USB selective suspend off: mouse and keyboard ports never doze. |
| `power-pcie-aspm-off` | MOS plan setting `ee12f906-d277-404b-b6da-e5fa1a576df5` = 0 | PCI Express link power management off (GPU, NIC). |
| `boot-no-platform-clock` | boot `useplatformclock` =  | Makes sure the timer is not forced onto HPET (a common "tweak" linked to stutter). Only removes the setting, never adds it. |
| `power-hibernation-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\Power\HibernateEnabled` = 0 | No hibernation file. |
| `power-fast-startup-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled` = 0 | Fast startup off: required for safe dual-booting (each OS sees the others' drives fully shut down). |

## network

| Id | Changes | Why |
|----|---------|-----|
| `nic-eee-off` | wired adapter `*EEE` = 0 | Energy-Efficient Ethernet off: no link sleep between packets. |
| `nic-advanced-eee-off` | wired adapter `AdvancedEEE` = 0 | Realtek Advanced EEE off. |
| `nic-green-ethernet-off` | wired adapter `EnableGreenEthernet` = 0 | Realtek Green Ethernet off. |
| `nic-power-saving-off` | wired adapter `PowerSavingMode` = 0 | Realtek power saving mode off. |
| `nic-gigabit-lite-off` | wired adapter `GigaLite` = 0 | Realtek Gigabit Lite (500 Mbps power mode) off. |
| `nic-auto-disable-gigabit-off` | wired adapter `AutoDisableGigabit` = 0 | Never drops to 100 Mbps to save power. |
| `nic-intel-eee-off` | wired adapter `EEELinkAdvertisement` = 0 | Intel EEE advertisement off. |
| `nic-intel-reduce-speed-off` | wired adapter `ReduceSpeedOnPowerDown` = 0 | Intel: keep link speed. |
| `nic-intel-ulp-off` | wired adapter `ULPMode` = 0 | Intel ultra low power mode off. |

## gpu

| Id | Changes | Why |
|----|---------|-----|
| `gpu-msi-mode` | `PCI\VEN_10DE*` `MSISupported` = 1 | GPU uses message-signaled interrupts instead of a shared line IRQ: lower interrupt latency. Takes effect after reboot. |
| `gpu-no-nvidia-app` | script `nvidia-app.ps1` | NVIDIA App and its overlay hook into games and run background services. Runs its uninstaller if present. |

## game

| Id | Changes | Why |
|----|---------|-----|
| `game-dvr-off` | `HKCU:\System\GameConfigStore\GameDVR_Enabled` = 0 | Background game recording off. |
| `game-capture-off` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR\AppCaptureEnabled` = 0 | App capture off. |
| `game-dvr-policy` | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR\AllowGameDVR` = 0 | Game DVR blocked by policy so updates cannot turn it back on. |
| `game-bar-controller-off` | `HKCU:\Software\Microsoft\GameBar\UseNexusForGameBarEnabled` = 0 | Controller Xbox button does not open Game Bar. |
| `game-mode-on` | `HKCU:\Software\Microsoft\GameBar\AutoGameModeEnabled` = 1 | Game Mode stays on: it pauses Windows Update work and gives the game priority. |
| `game-transparency-off` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\EnableTransparency` = 0 | No desktop blur effects. |
| `valorant-low-graphics` | `[ScalabilityGroups]` in VALORANT settings, 11 keys | Every graphics group at its lowest value in every account's settings file (backed up first). The game creates these files on first launch, so apply again after that. |
| `riot-client-at-logon` | script `riot-autostart.ps1` | Riot Client opens right after auto-logon. Skipped until the Riot Client is installed. |

## virtualization

| Id | Changes | Why |
|----|---------|-----|
| `feature-hyperv-off` | feature `Microsoft-Hyper-V-All` -> Disabled | Hyper-V puts Windows itself inside a virtual machine. |
| `feature-vm-platform-off` | feature `VirtualMachinePlatform` -> Disabled | VM platform (WSL2/Android) starts the hypervisor. |
| `feature-sandbox-off` | feature `Containers-DisposableClientVM` -> Disabled | Windows Sandbox starts the hypervisor. |
| `feature-app-guard-off` | feature `Windows-Defender-ApplicationGuard` -> Disabled | Application Guard starts the hypervisor (removed on newer builds). |
| `boot-hypervisor-off` | boot `hypervisorlaunchtype` = Off | The hypervisor never loads at boot. |
| `vbs-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\EnableVirtualizationBasedSecurity` = 0 | Virtualization-based security off (Windows 11 turns it on by default). |
| `hvci-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity\Enabled` = 0 | Memory integrity off: removes its per-driver-call overhead. |

## experimental

Never applied by default. Apply a group by id, reboot, bench, and keep it only if the comparison shows a real gain (see INSTALL.md, step 9).

| Id | Changes | Why | Bench result |
|----|---------|-----|--------------|
| `exp-spectre-override` | `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\FeatureSettingsOverride` = 3 | Turns off the Spectre v2 / Meltdown kernel mitigations only. Can help older CPUs. Reboot needed. | not tested yet |
| `exp-spectre-mask` | `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\FeatureSettingsOverrideMask` = 3 | Mask that goes with FeatureSettingsOverride. | not tested yet |
| `exp-hags-off` | `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode` = 1 | Hardware-accelerated GPU scheduling off (Windows 11 default is on). Results vary per game and driver. Reboot needed. | not tested yet |
| `exp-timer-global` | `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests` = 1 | Lets one process raise the timer resolution for the whole system (Windows 11 ignores it otherwise). Reboot needed. | not tested yet |
| `exp-timer-task` | script `timer-task.ps1` | Logon task that holds a 0.5 ms timer resolution. Use together with exp-timer-global. | not tested yet |
| `exp-mpo-off` | `HKLM:\SOFTWARE\Microsoft\Windows\Dwm\OverlayTestMode` = 5 | Multiplane overlay off. Fixes stutter/flicker on some NVIDIA setups; can hurt windowed flip mode, and some builds ignore it. Reboot needed. | not tested yet |
| `exp-priority-separation` | `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation` = 38 | Scheduler: short, variable time slices with the highest foreground boost (0x26; Windows default is 2). Effect is unproven; keep only on a measured gain. | not tested yet |
| `exp-fso-off` | script `fso-valorant.ps1` | Fullscreen optimizations off for the VALORANT executable (AppCompat layer). Riot narrowed the windowed/fullscreen latency gap in 2025, so expect little. Skipped until the game is installed. | not tested yet |
| `exp-gpu-irq-policy` | `PCI\VEN_10DE*` `DevicePolicy` = 4 | GPU interrupts go to one chosen processor (IrqPolicySpecifiedProcessors). Use with exp-gpu-irq-mask; bench with -WithCounters. Reboot needed. | not tested yet |
| `exp-gpu-irq-mask` | `PCI\VEN_10DE*` `AssignmentSetOverride` = 4 0 0 0 0 0 0 0 | The chosen processor: logical CPU 2 (first thread of the second core), away from CPU 0 where most interrupts land. | not tested yet |
| `exp-sysmain-off` | service `SysMain` -> Disabled | SysMain (Superfetch) off. Reports of stutter from it are anecdotal; on an SSD with spare RAM the loss is small. Keep only on a measured gain. | not tested yet |
| `exp-memory-compression-off` | script `memory-compression.ps1` | Memory compression off (saves the CPU cost of compressing pages; only sensible with plenty of free RAM). Restart needed. Needs admin to read. | not tested yet |
| `exp-windowed-optimizations` | script `dx-global-setting.ps1` | Optimizations for windowed games on (flip-model presentation for DX10/11 in windowed and borderless). Only matters if VALORANT runs windowed or borderless; can cause tearing. | not tested yet |
| `exp-defender-quiet` | script `defender-quiet.ps1` | Defender stays on, but skips the Riot folders and keeps scans to idle time at low CPU. Opt-in: excluding folders lowers protection for them. | not tested yet |
| `exp-vbs-on-vbs` | `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\EnableVirtualizationBasedSecurity` = 1 | Only if Riot requires it, or for Vanguard on-demand mode: VBS on. | not tested yet |
| `exp-vbs-on-hvci` | `HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity\Enabled` = 1 | Memory integrity on. | not tested yet |
| `exp-vbs-on-hypervisor` | boot `hypervisorlaunchtype` = Auto | VBS needs the hypervisor to load at boot. | not tested yet |
