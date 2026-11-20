# Boot setting of the running OS entry ({current}). Fields: Target (setting name), Value, or Remove = $true.
# Needs admin even to read.
function Get-MosBcdValue([string]$Name) {
    $out = & bcdedit.exe /enum '{current}' 2>&1
    if ($LASTEXITCODE) { throw "bcdedit needs administrator rights ($(@($out)[0]))" }
    foreach ($line in $out) {
        if ("$line" -match "^\s*$([regex]::Escape($Name))\s+(.+?)\s*$") { return $Matches[1] }
    }
    $null
}

Register-MosHandler -Type 'Bcd' -Handler @{
    Get   = {
        param($t)
        $v = Get-MosBcdValue $t.Target
        if ($null -eq $v) { @{ Absent = $true } } else { @{ Absent = $false; Value = $v } }
    }
    Set   = {
        param($t, $v)
        if ($v.Absent) { & bcdedit.exe /deletevalue '{current}' $t.Target | Out-Null; return }
        $out = & bcdedit.exe /set '{current}' $t.Target ([string]$v.Value) 2>&1
        if ($LASTEXITCODE) { throw "bcdedit /set $($t.Target) failed: $out" }
    }
    Equal = {
        param($a, $b, $t)
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        [string]::Equals([string]$a.Value, [string]$b.Value, [StringComparison]::OrdinalIgnoreCase)
    }
}
