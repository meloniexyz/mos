# Defender stays on. Adds exclusions for the Riot folders, and limits scheduled scans to idle time at 20% CPU.
$riot = @("$env:SystemDrive\Riot Games\VALORANT", "$env:SystemDrive\Riot Games\Riot Client")

function Get-DefenderQuiet {
    $p = Get-MpPreference -ErrorAction Stop
    $ex = @($p.ExclusionPath | Where-Object { $_ -and $_ -notlike 'N/A*' } | Sort-Object)
    @{ ExclusionPath = $ex; ScanAvgCPULoadFactor = [int]$p.ScanAvgCPULoadFactor; ScanOnlyIfIdleEnabled = [bool]$p.ScanOnlyIfIdleEnabled }
}

@{
    Get     = { param($t) @{ Absent = $false; Value = (Get-DefenderQuiet) } }
    Desired = {
        param($t, $cur)
        $ex = @(@($cur.Value.ExclusionPath) + $riot | Where-Object { $_ } | Sort-Object -Unique)
        @{ Absent = $false; Value = @{ ExclusionPath = $ex; ScanAvgCPULoadFactor = 20; ScanOnlyIfIdleEnabled = $true } }
    }
    Set     = {
        param($t, $v)
        $want = @($v.Value.ExclusionPath | Where-Object { $_ })
        $have = @((Get-DefenderQuiet).ExclusionPath)
        $remove = @($have | Where-Object { $want -notcontains $_ })
        $add = @($want | Where-Object { $have -notcontains $_ })
        if ($remove.Count) { Remove-MpPreference -ExclusionPath $remove -ErrorAction Stop }
        if ($add.Count) { Add-MpPreference -ExclusionPath $add -ErrorAction Stop }
        Set-MpPreference -ScanAvgCPULoadFactor ([int]$v.Value.ScanAvgCPULoadFactor) -ScanOnlyIfIdleEnabled ([bool]$v.Value.ScanOnlyIfIdleEnabled) -ErrorAction Stop
    }
}
