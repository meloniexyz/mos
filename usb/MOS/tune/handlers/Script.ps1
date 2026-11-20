# Custom tweak implemented in tune\scripts\<Script>.ps1, which returns @{ Get; Set; Desired (optional); Equal (optional) }.
Register-MosHandler -Type 'Script' -Handler @{
    Get     = { param($t) $s = Get-MosScript $t.Script; & $s.Get $t }
    Set     = { param($t, $v) $s = Get-MosScript $t.Script; & $s.Set $t $v }
    Desired = {
        param($t, $cur)
        $s = Get-MosScript $t.Script
        if ($s.Desired) { & $s.Desired $t $cur } else { @{ Absent = $false; Value = $t.Value } }
    }
    Equal   = {
        param($a, $b, $t)
        $s = Get-MosScript $t.Script
        if ($s.Equal) { return [bool](& $s.Equal $a $b $t) }
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        (ConvertTo-MosCanonical $a.Value) -eq (ConvertTo-MosCanonical $b.Value)
    }
}
