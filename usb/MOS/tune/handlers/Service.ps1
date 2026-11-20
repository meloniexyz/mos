# Service start type, read and written in the registry (works for per-user service templates too).
# Fields: Target (service name), Value: Disabled | Manual | Automatic | AutomaticDelayed.
# A missing service counts as satisfied when the MOS value is Disabled or Manual.
$script:MosServiceStart = @{ Automatic = 2; AutomaticDelayed = 2; Manual = 3; Disabled = 4 }

Register-MosHandler -Type 'Service' -Handler @{
    Get   = {
        param($t)
        $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$($t.Target)"
        if (-not (Test-Path -LiteralPath $k)) { return @{ Absent = $true } }
        $p = Get-ItemProperty -LiteralPath $k
        $start = $p.Start
        $delayed = if ($p.PSObject.Properties['DelayedAutostart']) { [int]$p.DelayedAutostart } else { 0 }
        $name = switch ([int]$start) { 0 { 'Boot' } 1 { 'System' } 2 { if ($delayed) { 'AutomaticDelayed' } else { 'Automatic' } } 3 { 'Manual' } 4 { 'Disabled' } default { "Start$start" } }
        @{ Absent = $false; Value = $name }
    }
    Set   = {
        param($t, $v)
        if ($v.Absent) { return }
        $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$($t.Target)"
        if (-not (Test-Path -LiteralPath $k)) { return }
        $start = switch ($v.Value) { 'Boot' { 0 } 'System' { 1 } default { $script:MosServiceStart[[string]$v.Value] } }
        if ($null -eq $start) { throw "Unknown start type '$($v.Value)'." }
        Set-ItemProperty -LiteralPath $k -Name Start -Value $start -Type DWord
        if ($start -eq 2) { Set-ItemProperty -LiteralPath $k -Name DelayedAutostart -Value ([int]($v.Value -eq 'AutomaticDelayed')) -Type DWord }
        if ($v.Value -eq 'Disabled') { Stop-Service -Name $t.Target -Force -NoWait -ErrorAction SilentlyContinue }
    }
    Equal = {
        param($a, $b, $t)
        if ($a.Absent) { return ($b.Absent -or $b.Value -in 'Disabled', 'Manual') }
        if ($b.Absent) { return $false }
        [string]$a.Value -eq [string]$b.Value
    }
}
