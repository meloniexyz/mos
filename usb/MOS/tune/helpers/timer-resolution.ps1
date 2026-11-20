# Holds the system timer at 0.5 ms while this process runs. Started at logon by the experimental 'exp-timer-task' tweak.
Add-Type -Namespace MOS -Name Timer -MemberDefinition @'
[DllImport("ntdll.dll")] public static extern int NtSetTimerResolution(uint DesiredResolution, bool SetResolution, out uint CurrentResolution);
'@
$current = [uint32]0
[void][MOS.Timer]::NtSetTimerResolution(5000, $true, [ref]$current)   # 5000 x 100 ns = 0.5 ms
[System.Threading.Thread]::Sleep([System.Threading.Timeout]::Infinite)
