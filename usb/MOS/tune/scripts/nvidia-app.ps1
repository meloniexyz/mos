# NVIDIA App (and with it the NVIDIA overlay). MOS value: not installed.
# Removal runs NVIDIA's own uninstaller (it may show a window). Undo: reinstall from nvidia.com by hand.
function Get-NvidiaAppEntry {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue | Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'NVIDIA App' } | Select-Object -First 1
}

@{
    Get     = { param($t) $e = Get-NvidiaAppEntry; if ($e) { @{ Absent = $false; Value = 'Present' } } else { @{ Absent = $true } } }
    Desired = { param($t, $cur) @{ Absent = $true } }
    Set     = {
        param($t, $v)
        if (-not $v.Absent) { throw 'Reinstall the NVIDIA App from nvidia.com if you want it back.' }
        $e = Get-NvidiaAppEntry
        if (-not $e) { return }
        $cmd = if ($e.PSObject.Properties['QuietUninstallString'] -and $e.QuietUninstallString) { $e.QuietUninstallString } else { $e.UninstallString }
        if (-not $cmd) { throw 'NVIDIA App has no uninstall command; remove it from Settings > Apps.' }
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Wait
    }
}
