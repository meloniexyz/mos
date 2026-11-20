# Preinstalled consumer apps and AI features. Apps are removed for the MOS user; their provisioned copy stays so undo can re-register them.
# Kept on purpose (keep-list): Store, WebView2, VC++ libs, App Installer, Windows Security UI.
@{
    Module = 'apps'
    Tweaks = @(
        @{ Id = 'app-bing-news'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.BingNews'; Why = 'News app, background refresh.' }
        @{ Id = 'app-bing-weather'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.BingWeather'; Why = 'Weather app, background refresh.' }
        @{ Id = 'app-bing-search'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.BingSearch'; Why = 'Bing search app.' }
        @{ Id = 'app-get-help'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.GetHelp'; Why = 'Not used on a game-only install.' }
        @{ Id = 'app-tips'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.Getstarted'; Why = 'Tips app and its notifications.' }
        @{ Id = 'app-office-hub'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.MicrosoftOfficeHub'; Why = 'Microsoft 365 promo app.' }
        @{ Id = 'app-solitaire'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.MicrosoftSolitaireCollection'; Why = 'Bundled game with ads.' }
        @{ Id = 'app-sticky-notes'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.MicrosoftStickyNotes'; Why = 'Syncs in the background.' }
        @{ Id = 'app-people'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.People'; Why = 'Contacts sync.' }
        @{ Id = 'app-power-automate'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.PowerAutomateDesktop'; Why = 'Not used.' }
        @{ Id = 'app-todo'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.Todos'; Why = 'Syncs in the background.' }
        @{ Id = 'app-alarms'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.WindowsAlarms'; Why = 'Not used.' }
        @{ Id = 'app-mail'; Tier = 'standard'; Type = 'Appx'; Target = 'microsoft.windowscommunicationsapps'; Why = 'Mail/Calendar sync.' }
        @{ Id = 'app-outlook'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.OutlookForWindows'; Why = 'New Outlook, background sync.' }
        @{ Id = 'app-feedback-hub'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.WindowsFeedbackHub'; Why = 'Telemetry prompts.' }
        @{ Id = 'app-maps'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.WindowsMaps'; Why = 'Map downloads in the background.' }
        @{ Id = 'app-sound-recorder'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.WindowsSoundRecorder'; Why = 'Not used.' }
        @{ Id = 'app-phone-link'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.YourPhone'; Why = 'Phone Link keeps a background connection.' }
        @{ Id = 'app-cross-device'; Tier = 'standard'; Type = 'Appx'; Target = 'MicrosoftWindows.CrossDevice'; Why = 'Cross-device experience host.' }
        @{ Id = 'app-media-player'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.ZuneMusic'; Why = 'Media Player, indexes the music library.' }
        @{ Id = 'app-movies'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.ZuneVideo'; Why = 'Not used.' }
        @{ Id = 'app-clipchamp'; Tier = 'standard'; Type = 'Appx'; Target = 'Clipchamp.Clipchamp'; Why = 'Video editor promo.' }
        @{ Id = 'app-quick-assist'; Tier = 'standard'; Type = 'Appx'; Target = 'MicrosoftCorporationII.QuickAssist'; Why = 'Remote help, not needed.' }
        @{ Id = 'app-family'; Tier = 'standard'; Type = 'Appx'; Target = 'MicrosoftCorporationII.MicrosoftFamily'; Why = 'Family safety app.' }
        @{ Id = 'app-teams'; Tier = 'standard'; Type = 'Appx'; Target = 'MSTeams'; Why = 'Teams starts with Windows.' }
        @{ Id = 'app-copilot'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.Copilot'; Why = 'Copilot app.' }
        @{ Id = 'app-cortana'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.549981C3F5F10'; Why = 'Cortana (older builds).' }
        @{ Id = 'app-devhome'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.Windows.DevHome'; Why = 'Dev Home, not needed.' }
        @{ Id = 'app-widgets'; Tier = 'standard'; Type = 'Appx'; Target = 'MicrosoftWindows.Client.WebExperience'; Why = 'Widgets board and its web host.' }
        @{ Id = 'app-xbox'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.GamingApp'; Why = 'Xbox app; VALORANT does not use it.' }
        @{ Id = 'app-xbox-legacy'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.XboxApp'; Why = 'Old Xbox Console Companion.' }
        @{ Id = 'app-game-bar'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.XboxGamingOverlay'; Why = 'Game Bar overlay hooks into games.' }
        @{ Id = 'app-xbox-speech'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.XboxSpeechToTextOverlay'; Why = 'Xbox overlay component.' }
        @{ Id = 'app-xbox-tcui'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.Xbox.TCUI'; Why = 'Xbox overlay component.' }
        @{ Id = 'app-xbox-identity'; Tier = 'standard'; Type = 'Appx'; Target = 'Microsoft.XboxIdentityProvider'; Why = 'Xbox sign-in, not used.' }

        @{ Id = 'app-onedrive'; Tier = 'standard'; Type = 'Script'; Script = 'onedrive'; Why = 'OneDrive syncs and scans files in the background. Undo reinstalls it with the setup that ships in Windows.' }

        # Edge stays installed (Windows components and WebView2 rely on it) but never runs in the background.
        @{ Id = 'edge-no-startup-boost'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0; ValueType = 'DWord'; Why = 'Stops Edge preloading at logon.' }
        @{ Id = 'edge-no-background'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0; ValueType = 'DWord'; Why = 'Edge exits when its window closes.' }
        @{ Id = 'edge-update-svc'; Tier = 'standard'; Type = 'Service'; Target = 'edgeupdate'; Value = 'Manual'; Why = 'Edge updater runs only when needed.' }
        @{ Id = 'edge-update-svc-m'; Tier = 'standard'; Type = 'Service'; Target = 'edgeupdatem'; Value = 'Manual'; Why = 'Edge updater runs only when needed.' }

        # AI and suggested-content features
        @{ Id = 'policy-no-copilot'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; ValueType = 'DWord'; Why = 'Turns off Windows Copilot.' }
        @{ Id = 'policy-no-recall'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1; ValueType = 'DWord'; Why = 'Recall snapshots off.' }
        @{ Id = 'feature-recall'; Tier = 'standard'; Type = 'OptionalFeature'; Target = 'Recall'; Value = 'Disabled'; Why = 'Recall component off (skipped where it does not exist).' }
        @{ Id = 'policy-no-widgets'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; ValueType = 'DWord'; Why = 'Widgets board off.' }
        @{ Id = 'policy-no-consumer-apps'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Value = 1; ValueType = 'DWord'; Why = 'Stops Windows from installing suggested apps.' }
        @{ Id = 'no-silent-app-installs'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Value = 0; ValueType = 'DWord'; Why = 'No sponsored app installs.' }
        @{ Id = 'no-start-suggestions'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Value = 0; ValueType = 'DWord'; Why = 'No Start menu suggestions.' }
        @{ Id = 'no-web-search'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1; ValueType = 'DWord'; Why = 'Start search stays local, no Bing calls.' }
        @{ Id = 'no-background-apps'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Value = 2; ValueType = 'DWord'; Why = 'Store apps cannot run in the background. The Riot Client is a desktop app and is not affected.' }
    )
}
