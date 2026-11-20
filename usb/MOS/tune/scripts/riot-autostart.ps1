# Riot Client in the current user's Run key so it opens after auto-logon. Skipped until the Riot Client is installed.
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$valueName = 'MOS-RiotClient'

function Find-RiotClient {
    $installs = Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json'
    if (Test-Path -LiteralPath $installs) {
        try {
            $j = Get-Content -LiteralPath $installs -Raw | ConvertFrom-Json
            foreach ($p in 'rc_live', 'rc_default') {
                if ($j.PSObject.Properties[$p] -and $j.$p -and (Test-Path -LiteralPath $j.$p)) { return ($j.$p -replace '/', '\') }
            }
        }
        catch { }
    }
    $fallback = Join-Path $env:SystemDrive 'Riot Games\Riot Client\RiotClientServices.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    $null
}

@{
    Get     = {
        param($t)
        $v = (Get-ItemProperty -LiteralPath $runKey -ErrorAction SilentlyContinue).$valueName
        if ($v) { @{ Absent = $false; Value = $v } } else { @{ Absent = $true } }
    }
    Desired = {
        param($t, $cur)
        $exe = Find-RiotClient
        if (-not $exe) { return @{ Skip = 'Riot Client not installed yet (install it, then apply again)' } }
        @{ Absent = $false; Value = ('"{0}"' -f $exe) }
    }
    Set     = {
        param($t, $v)
        if ($v.Absent) { Remove-ItemProperty -LiteralPath $runKey -Name $valueName -ErrorAction SilentlyContinue; return }
        New-ItemProperty -LiteralPath $runKey -Name $valueName -Value $v.Value -PropertyType String -Force | Out-Null
    }
}
