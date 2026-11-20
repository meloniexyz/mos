# One "Key=Value;" pair inside the DirectXUserGlobalSettings string (Settings > Graphics > Advanced graphics).
# Other pairs in the string are kept. Undo restores the exact previous string, or removes it if it was absent.
# Tweak fields: Key, Value. Test hook: RegKey overrides the registry key.
$defaultKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$valueName = 'DirectXUserGlobalSettings'

function Get-DxKey($t) { if ($t['RegKey']) { $t['RegKey'] } else { $defaultKey } }

function Read-DxString($t) {
    $k = Get-DxKey $t
    if (-not (Test-Path -LiteralPath $k)) { return $null }
    $item = Get-Item -LiteralPath $k
    if (@($item.GetValueNames()) -contains $valueName) { return [string]$item.GetValue($valueName) }
    $null
}

function Set-DxPair([string]$Current, [string]$Key, [string]$Value) {
    $pairs = New-Object System.Collections.Generic.List[string]
    $found = $false
    foreach ($p in ([string]$Current -split ';')) {
        if (-not $p.Trim()) { continue }
        $name = ($p -split '=', 2)[0].Trim()
        if ($name -ieq $Key) { $pairs.Add("$Key=$Value"); $found = $true } else { $pairs.Add($p.Trim()) }
    }
    if (-not $found) { $pairs.Add("$Key=$Value") }
    ($pairs -join ';') + ';'
}

@{
    Get     = { param($t) $s = Read-DxString $t; if ($null -eq $s) { @{ Absent = $true } } else { @{ Absent = $false; Value = $s } } }
    Desired = { param($t, $cur) @{ Absent = $false; Value = (Set-DxPair $(if ($cur.Absent) { '' } else { $cur.Value }) $t.Key ([string]$t.Value)) } }
    Equal   = {
        param($a, $b, $t)
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        [string]$a.Value -eq [string]$b.Value
    }
    Set     = {
        param($t, $v)
        $k = Get-DxKey $t
        if ($v.Absent) { if (Test-Path -LiteralPath $k) { Remove-ItemProperty -LiteralPath $k -Name $valueName -ErrorAction SilentlyContinue }; return }
        if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
        New-ItemProperty -LiteralPath $k -Name $valueName -Value ([string]$v.Value) -PropertyType String -Force | Out-Null
    }
}
