# Scheduled task enabled/disabled. Fields: Target (full path, e.g. \Microsoft\Windows\Maps\MapsUpdateTask), Value: Disabled | Enabled.
# A missing task counts as satisfied when the MOS value is Disabled.
Register-MosHandler -Type 'ScheduledTask' -Handler @{
    Get   = {
        param($t)
        $p = Split-MosTaskPath $t.Target
        $task = Get-ScheduledTask -TaskPath $p.Path -TaskName $p.Name -ErrorAction SilentlyContinue
        if (-not $task) { return @{ Absent = $true } }
        @{ Absent = $false; Value = $(if ($task.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' }) }
    }
    Set   = {
        param($t, $v)
        if ($v.Absent) { return }
        $p = Split-MosTaskPath $t.Target
        if ($v.Value -eq 'Disabled') { Disable-ScheduledTask -TaskPath $p.Path -TaskName $p.Name -ErrorAction Stop | Out-Null }
        else { Enable-ScheduledTask -TaskPath $p.Path -TaskName $p.Name -ErrorAction Stop | Out-Null }
    }
    Equal = {
        param($a, $b, $t)
        if ($a.Absent) { return ($b.Absent -or $b.Value -eq 'Disabled') }
        if ($b.Absent) { return $false }
        [string]$a.Value -eq [string]$b.Value
    }
}
