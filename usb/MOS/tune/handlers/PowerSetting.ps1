# Power plan setting (AC and DC index). Fields: Scheme ('MOS' or a plan GUID), Subgroup GUID, Setting GUID, Value (int).
# Read from the registry (works for hidden settings and without admin), written with powercfg.
function Resolve-MosScheme([string]$Scheme) { if ($Scheme -eq 'MOS') { Get-MosPlanGuid } else { $Scheme } }

function Get-MosActiveScheme {
    $out = powercfg /getactivescheme
    if ("$out" -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { return $Matches[1].ToLower() }
    $null
}

Register-MosHandler -Type 'PowerSetting' -Handler @{
    Get   = {
        param($t)
        $g = Resolve-MosScheme $t.Scheme
        $plan = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$g"
        if (-not (Test-Path -LiteralPath $plan)) { return @{ Absent = $true } }   # plan not created yet
        $own = "$plan\$($t.Subgroup)\$($t.Setting)"
        if (Test-Path -LiteralPath $own) {
            $v = (Get-ItemProperty -LiteralPath $own).ACSettingIndex
            if ($null -ne $v) { return @{ Absent = $false; Value = [int]$v } }
        }
        $default = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$($t.Subgroup)\$($t.Setting)\DefaultPowerSchemeValues\$g"
        if (Test-Path -LiteralPath $default) { return @{ Absent = $false; Value = [int](Get-ItemProperty -LiteralPath $default).ACSettingIndex } }
        @{ Absent = $false; Value = $null }   # plan uses an inherited default we can't read
    }
    Set   = {
        param($t, $v)
        if ($v.Absent -or $null -eq $v.Value) { return }   # nothing recorded to restore; the plan switch handles undo
        $g = Resolve-MosScheme $t.Scheme
        powercfg /setacvalueindex $g $t.Subgroup $t.Setting ([int]$v.Value) | Out-Null
        if ($LASTEXITCODE) { throw "powercfg /setacvalueindex failed ($LASTEXITCODE). Is the plan '$g' created?" }
        powercfg /setdcvalueindex $g $t.Subgroup $t.Setting ([int]$v.Value) | Out-Null
        if ((Get-MosActiveScheme) -eq $g) { powercfg /setactive $g | Out-Null }
    }
    Equal = {
        param($a, $b, $t)
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        if ($null -eq $b.Value) { return $true }
        "$($a.Value)" -eq "$($b.Value)"
    }
}
