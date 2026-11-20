# Memory compression (MMAgent). MOS value: off. Needs admin to read and change; takes effect after a restart.
@{
    Get     = {
        param($t)
        $a = Get-MMAgent -ErrorAction Stop   # throws without admin -> reported as unknown by check
        @{ Absent = $false; Value = $(if ($a.MemoryCompression) { 'On' } else { 'Off' }) }
    }
    Desired = { param($t, $cur) @{ Absent = $false; Value = 'Off' } }
    Set     = {
        param($t, $v)
        if ($v.Value -eq 'Off') { Disable-MMAgent -MemoryCompression -ErrorAction Stop } else { Enable-MMAgent -MemoryCompression -ErrorAction Stop }
    }
}
