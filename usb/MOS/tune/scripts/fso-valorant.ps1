# Fullscreen optimizations off for the VALORANT executable via the AppCompat "Layers" value.
# Other compatibility tokens already on that executable are kept. Skipped until the game is installed.
# Test hooks: tweak fields ExePath and LayersKey override the defaults.
$defaultLayers = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$token = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'

function Find-ValorantExe($t) {
    if ($t['ExePath']) { if (Test-Path -LiteralPath $t['ExePath']) { return $t['ExePath'] } else { return $null } }
    $settings = Join-Path $env:ProgramData 'Riot Games\Metadata\valorant.live\valorant.live.product_settings.yaml'
    $roots = @()
    if (Test-Path -LiteralPath $settings) {
        $m = Select-String -LiteralPath $settings -Pattern 'product_install_full_path:\s*"?([^"\r\n]+)"?' | Select-Object -First 1
        if ($m) { $roots += ($m.Matches[0].Groups[1].Value.Trim() -replace '/', '\') }
    }
    $roots += (Join-Path $env:SystemDrive 'Riot Games\VALORANT\live')
    foreach ($r in $roots) {
        $exe = Join-Path $r 'ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe'
        if (Test-Path -LiteralPath $exe) { return $exe }
    }
    $null
}

function Get-LayersKey($t) { if ($t['LayersKey']) { $t['LayersKey'] } else { $defaultLayers } }

function Read-Layer($t, [string]$Exe) {
    $key = Get-LayersKey $t
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $item = Get-Item -LiteralPath $key
    if (@($item.GetValueNames()) -contains $Exe) { return [string]$item.GetValue($Exe) }
    $null
}

@{
    Get     = {
        param($t)
        $exe = Find-ValorantExe $t
        if (-not $exe) { return @{ Absent = $true } }
        $v = Read-Layer $t $exe
        if ($null -eq $v) { @{ Absent = $true; Exe = $exe } } else { @{ Absent = $false; Value = $v; Exe = $exe } }
    }
    Desired = {
        param($t, $cur)
        $exe = Find-ValorantExe $t
        if (-not $exe) { return @{ Skip = 'VALORANT is not installed yet (install it, then apply again)' } }
        $tokens = @()
        if (-not $cur.Absent) { $tokens = @(([string]$cur.Value -split '\s+') | Where-Object { $_ -and $_ -ne '~' }) }
        if ($tokens -notcontains $token) { $tokens += $token }
        @{ Absent = $false; Value = ('~ ' + ($tokens -join ' ')); Exe = $exe }
    }
    Equal   = {
        param($a, $b, $t)
        if ($a.Absent -or $b.Absent) { return ([bool]$a.Absent -eq [bool]$b.Absent) }
        [string]$a.Value -eq [string]$b.Value
    }
    Set     = {
        param($t, $v)
        $exe = if ($v.Exe) { [string]$v.Exe } else { Find-ValorantExe $t }
        if (-not $exe) { throw 'VALORANT executable not found.' }
        $key = Get-LayersKey $t
        if ($v.Absent) { if (Test-Path -LiteralPath $key) { Remove-ItemProperty -LiteralPath $key -Name $exe -ErrorAction SilentlyContinue }; return }
        if (-not (Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
        New-ItemProperty -LiteralPath $key -Name $exe -Value ([string]$v.Value) -PropertyType String -Force | Out-Null
    }
}
