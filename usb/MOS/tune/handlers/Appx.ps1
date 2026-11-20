# Store app for the current user. Fields: Target (package name, wildcards allowed). MOS value: removed.
# The provisioned copy is kept on purpose, so undo can re-register the app from its install folder.
Register-MosHandler -Type 'Appx' -Handler @{
    Get     = {
        param($t)
        $pkgs = @(Get-AppxPackage -Name $t.Target -ErrorAction SilentlyContinue)
        if (-not $pkgs.Count) { return @{ Absent = $true } }
        @{ Absent = $false; Value = 'Present'; Packages = @($pkgs | ForEach-Object { $_.PackageFullName }); Locations = @($pkgs | ForEach-Object { $_.InstallLocation }) }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) {
            foreach ($p in @(Get-AppxPackage -Name $t.Target -ErrorAction SilentlyContinue)) { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop }
            return
        }
        foreach ($loc in @($v.Locations)) {
            $manifest = Join-Path $loc 'AppxManifest.xml'
            if (-not (Test-Path -LiteralPath $manifest)) { throw "Can't restore $($t.Target): $manifest is gone. Reinstall it from the Microsoft Store." }
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
        }
    }
    Desired = { param($t, $cur) @{ Absent = $true } }
    Equal   = { param($a, $b, $t) [bool]$a.Absent -eq [bool]$b.Absent }
}
