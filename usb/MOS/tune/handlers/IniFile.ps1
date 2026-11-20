# Keys in one [Section] of every INI file matching Path (wildcards and %ENV% allowed, string or array).
# Fields: Path, Section, Settings (hashtable key -> string), optional Exclude (wildcards), optional RefuseWhileRunning (process name).
# Before the first change each file is copied to <file>.mos-backup. File encoding is preserved.

function Get-MosIniFiles($t) {
    $files = foreach ($p in @($t.Path)) {
        $expanded = [Environment]::ExpandEnvironmentVariables([string]$p)
        Get-Item -Path $expanded -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
    }
    $files = @($files | Sort-Object FullName -Unique)
    foreach ($x in @($t['Exclude'])) { if ($x) { $files = @($files | Where-Object { $_.FullName -notlike $x }) } }
    $files
}

function Read-MosIni([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $enc = if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { [Text.Encoding]::Unicode }
    elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { New-Object Text.UTF8Encoding $true }
    else { New-Object Text.UTF8Encoding $false }
    $text = [IO.File]::ReadAllText($Path, $enc)
    $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    @{ Lines = [Collections.Generic.List[string]]($text -split "`r?`n"); Encoding = $enc; NewLine = $nl }
}

function Get-MosIniSectionRange($lines, [string]$Section) {
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "[$Section]") { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i].TrimStart().StartsWith('[')) { return @{ Start = $start; End = $i } }
    }
    if ($start -ge 0) { return @{ Start = $start; End = $lines.Count } }
    $null
}

function Get-MosIniValues([string]$Path, [string]$Section, $Keys) {
    $ini = Read-MosIni $Path
    $range = Get-MosIniSectionRange $ini.Lines $Section
    $out = @{}
    foreach ($k in $Keys) { $out[$k] = $null }
    if ($range) {
        for ($i = $range.Start + 1; $i -lt $range.End; $i++) {
            if ($ini.Lines[$i] -match '^\s*([^=;#\s][^=]*?)\s*=(.*)$' -and $out.ContainsKey($Matches[1])) { $out[$Matches[1]] = $Matches[2].Trim() }
        }
    }
    $out
}

function Set-MosIniValues([string]$Path, [string]$Section, $Values) {
    $ini = Read-MosIni $Path
    $lines = $ini.Lines
    # drop trailing empty line produced by a final newline; it is re-added on write
    $hadFinalNewline = ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '')
    if ($hadFinalNewline) { $lines.RemoveAt($lines.Count - 1) }
    $range = Get-MosIniSectionRange $lines $Section
    if (-not $range) {
        if ($lines.Count -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
        $lines.Add("[$Section]")
        $range = @{ Start = $lines.Count - 1; End = $lines.Count }
    }
    foreach ($k in @($Values.Keys)) {
        $found = -1
        for ($i = $range.Start + 1; $i -lt $range.End; $i++) {
            if ($lines[$i] -match '^\s*([^=;#\s][^=]*?)\s*=' -and $Matches[1] -eq $k) { $found = $i; break }
        }
        $val = $Values[$k]
        if ($null -eq $val) {
            if ($found -ge 0) { $lines.RemoveAt($found); $range.End-- }
        }
        elseif ($found -ge 0) { $lines[$found] = "$k=$val" }
        else {
            # insert after the last non-empty line of the section
            $at = $range.End
            while ($at -gt $range.Start + 1 -and $lines[$at - 1].Trim() -eq '') { $at-- }
            $lines.Insert($at, "$k=$val"); $range.End++
        }
    }
    $text = ($lines -join $ini.NewLine) + $(if ($hadFinalNewline) { $ini.NewLine } else { '' })
    [IO.File]::WriteAllText($Path, $text, $ini.Encoding)
}

Register-MosHandler -Type 'IniFile' -Handler @{
    Get     = {
        param($t)
        $files = Get-MosIniFiles $t
        if (-not $files.Count) { return @{ Absent = $true } }
        $map = @{}
        foreach ($f in $files) { $map[$f.FullName] = Get-MosIniValues $f.FullName $t.Section @($t.Settings.Keys) }
        @{ Absent = $false; Value = $map }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) { return }
        if ($t['RefuseWhileRunning'] -and (Get-Process -Name $t.RefuseWhileRunning -ErrorAction SilentlyContinue)) {
            throw "Close $($t.RefuseWhileRunning) first; it rewrites this file on exit."
        }
        foreach ($file in @($v.Value.Keys)) {
            if (-not (Test-Path -LiteralPath $file)) { continue }
            $bak = "$file.mos-backup"
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $file -Destination $bak }
            Set-MosIniValues $file $t.Section $v.Value[$file]
        }
    }
    Desired = {
        param($t, $cur)
        if ($cur.Absent) { return @{ Skip = 'no matching settings file yet (launch the game once, then apply again)' } }
        $map = @{}
        foreach ($file in @($cur.Value.Keys)) {
            $vals = @{}
            foreach ($k in @($t.Settings.Keys)) { $vals[$k] = [string]$t.Settings[$k] }
            $map[$file] = $vals
        }
        @{ Absent = $false; Value = $map }
    }
}
