# Advanced property on every physical wired adapter that exposes it. Fields: Target (registry keyword, e.g. '*EEE'), Value (string).
# Adapters without the keyword are ignored; if no adapter has it the tweak is skipped.
function Get-MosWiredAdapters {
    @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.PhysicalMediaType -eq '802.3' })
}

Register-MosHandler -Type 'NetAdapterProperty' -Handler @{
    Get     = {
        param($t)
        $map = @{}
        foreach ($a in Get-MosWiredAdapters) {
            $p = Get-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $t.Target -ErrorAction SilentlyContinue
            if ($p) { $map[$a.Name] = [string](@($p.RegistryValue)[0]) }
        }
        if (-not $map.Count) { return @{ Absent = $true } }
        @{ Absent = $false; Value = $map }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) { return }
        foreach ($name in @($v.Value.Keys)) {
            Set-NetAdapterAdvancedProperty -Name $name -RegistryKeyword $t.Target -RegistryValue ([string]$v.Value[$name]) -NoRestart -ErrorAction Stop
        }
    }
    Desired = {
        param($t, $cur)
        if ($cur.Absent) { return @{ Skip = "no wired adapter exposes '$($t.Target)'" } }
        $map = @{}
        foreach ($k in @($cur.Value.Keys)) { $map[$k] = [string]$t.Value }
        @{ Absent = $false; Value = $map }
    }
}
