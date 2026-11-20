# Windows optional feature. Fields: Target (feature name), Value: Disabled | Enabled.
# Read via DISM when elevated (shows pending states), via WMI otherwise. Changes take effect after a reboot.
# A feature that doesn't exist on this build counts as satisfied when the MOS value is Disabled.
Register-MosHandler -Type 'OptionalFeature' -Handler @{
    Get   = {
        param($t)
        try {
            $f = Get-WindowsOptionalFeature -Online -FeatureName $t.Target -ErrorAction Stop
            if (-not $f) { return @{ Absent = $true } }
            $s = [string]$f.State
            if ($s -like 'Enable*') { return @{ Absent = $false; Value = 'Enabled'; Pending = ($s -like '*Pending') } }
            if ($s -like 'Disable*') { return @{ Absent = $false; Value = 'Disabled'; Pending = ($s -like '*Pending') } }
            return @{ Absent = $true }
        }
        catch {
            $w = Get-CimInstance Win32_OptionalFeature -Filter "Name='$($t.Target)'" -ErrorAction SilentlyContinue
            if (-not $w -or $w.InstallState -eq 3) { return @{ Absent = $true } }
            @{ Absent = $false; Value = $(if ($w.InstallState -eq 1) { 'Enabled' } else { 'Disabled' }) }
        }
    }
    Set   = {
        param($t, $v)
        if ($v.Absent) { return }
        if ($v.Value -eq 'Disabled') { Disable-WindowsOptionalFeature -Online -FeatureName $t.Target -NoRestart -ErrorAction Stop | Out-Null }
        else { Enable-WindowsOptionalFeature -Online -FeatureName $t.Target -All -NoRestart -ErrorAction Stop | Out-Null }
    }
    Equal = {
        param($a, $b, $t)
        if ($a.Absent) { return ($b.Absent -or $b.Value -eq 'Disabled') }
        if ($b.Absent) { return $false }
        [string]$a.Value -eq [string]$b.Value
    }
}
