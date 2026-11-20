# OneDrive for the current user. MOS value: not installed. Undo reinstalls with the OneDriveSetup.exe that ships in Windows.
function Find-OneDriveExe {
    foreach ($p in "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    $null
}
function Find-OneDriveSetup {
    $c = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe")
    $c += @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive\*\OneDriveSetup.exe", "$env:ProgramFiles\Microsoft OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName)
    foreach ($p in $c) { if (Test-Path -LiteralPath $p) { return $p } }
    $null
}

@{
    Get     = { param($t) if (Find-OneDriveExe) { @{ Absent = $false; Value = 'Present' } } else { @{ Absent = $true } } }
    Desired = { param($t, $cur) @{ Absent = $true } }
    Set     = {
        param($t, $v)
        $setup = Find-OneDriveSetup
        if ($v.Absent) {
            if (-not (Find-OneDriveExe)) { return }
            if (-not $setup) { throw 'OneDriveSetup.exe not found; uninstall OneDrive from Settings > Apps.' }
            Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait
        }
        else {
            if (-not $setup) { throw 'OneDriveSetup.exe not found; download OneDrive from microsoft.com to reinstall.' }
            Start-Process -FilePath $setup -Wait
        }
    }
}
