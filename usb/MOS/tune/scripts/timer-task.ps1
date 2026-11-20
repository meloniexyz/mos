# Logon task "MOS-TimerResolution" that runs helpers\timer-resolution.ps1 (holds a 0.5 ms timer).
$taskName = 'MOS-TimerResolution'
$helper = Join-Path (Split-Path $PSScriptRoot -Parent) 'helpers\timer-resolution.ps1'

function Stop-TimerHelper {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*timer-resolution.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

@{
    Get     = { param($t) if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { @{ Absent = $false; Value = 'Present' } } else { @{ Absent = $true } } }
    Desired = { param($t, $cur) @{ Absent = $false; Value = 'Present' } }
    Set     = {
        param($t, $v)
        if ($v.Absent) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            Stop-TimerHelper
            return
        }
        if (-not (Test-Path -LiteralPath $helper)) { throw "Helper not found: $helper" }
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $helper)
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'MOS: hold 0.5 ms timer resolution (experimental)' -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
    }
}
