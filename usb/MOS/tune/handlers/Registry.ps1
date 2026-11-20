# Registry value. Fields: Target (HKLM:\ or HKCU:\ key), Name, Value + ValueType, or Remove = $true.
Register-MosHandler -Type 'Registry' -Handler @{
    Get     = {
        param($t)
        if (-not (Test-Path -LiteralPath $t.Target)) { return @{ Absent = $true } }
        $key = Get-Item -LiteralPath $t.Target
        if (@($key.GetValueNames()) -notcontains $t.Name) { return @{ Absent = $true } }
        @{ Absent = $false; Value = $key.GetValue($t.Name, $null, 'DoNotExpandEnvironmentNames'); ValueType = $key.GetValueKind($t.Name).ToString() }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) {
            if (Test-Path -LiteralPath $t.Target) { Remove-ItemProperty -LiteralPath $t.Target -Name $t.Name -ErrorAction SilentlyContinue }
            return
        }
        if (-not (Test-Path -LiteralPath $t.Target)) { New-Item -Path $t.Target -Force | Out-Null }
        $type = if ($v.ValueType) { $v.ValueType } else { $t.ValueType }
        New-ItemProperty -LiteralPath $t.Target -Name $t.Name -Value $v.Value -PropertyType $type -Force | Out-Null
    }
    Desired = {
        param($t, $cur)
        if ($t['Remove']) { @{ Absent = $true } } else { @{ Absent = $false; Value = $t.Value; ValueType = $t.ValueType } }
    }
    Equal   = {
        param($a, $b, $t)
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        (ConvertTo-MosCanonical $a.Value) -eq (ConvertTo-MosCanonical $b.Value)
    }
}
