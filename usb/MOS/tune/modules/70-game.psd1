# Capture/overlay off, Game Mode on, VALORANT low-graphics profile, Riot Client at logon.
@{
    Module = 'game'
    Tweaks = @(
        @{ Id = 'game-dvr-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; ValueType = 'DWord'; Why = 'Background game recording off.' }
        @{ Id = 'game-capture-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0; ValueType = 'DWord'; Why = 'App capture off.' }
        @{ Id = 'game-dvr-policy'; Tier = 'standard'; Type = 'Registry'; Target = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0; ValueType = 'DWord'; Why = 'Game DVR blocked by policy so updates cannot turn it back on.' }
        @{ Id = 'game-bar-controller-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\GameBar'; Name = 'UseNexusForGameBarEnabled'; Value = 0; ValueType = 'DWord'; Why = 'Controller Xbox button does not open Game Bar.' }
        @{ Id = 'game-mode-on'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Value = 1; ValueType = 'DWord'; Why = 'Game Mode stays on: it pauses Windows Update work and gives the game priority.' }
        @{ Id = 'game-transparency-off'; Tier = 'standard'; Type = 'Registry'; Target = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; ValueType = 'DWord'; Why = 'No desktop blur effects.' }

        @{ Id = 'valorant-low-graphics'; Tier = 'standard'; Type = 'IniFile'
           Path = @('%LOCALAPPDATA%\VALORANT\Saved\Config\*\WindowsClient\GameUserSettings.ini', '%LOCALAPPDATA%\VALORANT\Saved\Config\WindowsClient\GameUserSettings.ini')
           Exclude = @('*\_backup*'); Section = 'ScalabilityGroups'; RefuseWhileRunning = 'VALORANT-Win64-Shipping'
           Settings = @{
               'sg.ResolutionQuality' = '100'; 'sg.ViewDistanceQuality' = '0'; 'sg.AntiAliasingQuality' = '0'; 'sg.ShadowQuality' = '0'
               'sg.GlobalIlluminationQuality' = '0'; 'sg.ReflectionQuality' = '0'; 'sg.PostProcessQuality' = '0'; 'sg.TextureQuality' = '0'
               'sg.EffectsQuality' = '0'; 'sg.FoliageQuality' = '0'; 'sg.ShadingQuality' = '0'
           }
           Why = 'Every graphics group at its lowest value in every account''s settings file (backed up first). The game creates these files on first launch, so apply again after that.' }

        @{ Id = 'riot-client-at-logon'; Tier = 'standard'; Type = 'Script'; Script = 'riot-autostart'; Why = 'Riot Client opens right after auto-logon. Skipped until the Riot Client is installed.' }
    )
}
