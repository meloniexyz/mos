# Registry value under each matching device's hardware key (e.g. MSI interrupt mode).
# Fields: Class (PnP class), InstancePattern (wildcard on InstanceId), SubKey, Name, Value, ValueType.
# Registry values come back from JSON/psd1 as plain numbers or arrays; Binary must be written as byte[].
function ConvertTo-MosRegValue($Value, [string]$ValueType) {
    # leading comma: return the byte[] as one object; otherwise PowerShell unrolls it into object[]
    if ($ValueType -eq 'Binary') { return , ([byte[]]@($Value | ForEach-Object { [byte]$_ })) }
    $Value
}

function Get-MosPnpDevices($t) {
    @(Get-PnpDevice -Class $t.Class -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -like $t.InstancePattern })
}

Register-MosHandler -Type 'PnpRegistry' -Handler @{
    Get     = {
        param($t)
        $devs = @(Get-MosPnpDevices $t)   # @() matters: .Count on a single CimInstance reads a CIM property, not 1
        if (-not $devs.Count) { return @{ Absent = $true } }
        $map = @{}
        foreach ($d in $devs) {
            $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.InstanceId)\$($t.SubKey)"
            $val = $null
            if (Test-Path -LiteralPath $k) {
                $item = Get-Item -LiteralPath $k
                if (@($item.GetValueNames()) -contains $t.Name) { $val = $item.GetValue($t.Name) }
            }
            $map[$d.InstanceId] = $(if ($null -eq $val) { @{ Absent = $true } } else { @{ Absent = $false; Value = $val } })
        }
        @{ Absent = $false; Value = $map }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) { return }
        foreach ($id in @($v.Value.Keys)) {
            $k = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\$($t.SubKey)"
            $e = $v.Value[$id]
            if ($e.Absent) { if (Test-Path -LiteralPath $k) { Remove-ItemProperty -LiteralPath $k -Name $t.Name -ErrorAction SilentlyContinue }; continue }
            if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
            New-ItemProperty -LiteralPath $k -Name $t.Name -Value (ConvertTo-MosRegValue $e.Value $t.ValueType) -PropertyType $t.ValueType -Force | Out-Null
        }
    }
    Desired = {
        param($t, $cur)
        if ($cur.Absent) { return @{ Skip = "no present $($t.Class) device matches $($t.InstancePattern)" } }
        $map = @{}
        foreach ($k in @($cur.Value.Keys)) { $map[$k] = @{ Absent = $false; Value = $t.Value } }
        @{ Absent = $false; Value = $map }
    }
}
