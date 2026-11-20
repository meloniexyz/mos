#Requires -Version 5.1
<#
.SYNOPSIS
  Run on MOS (admin). Copies VALORANT from the daily Windows 10's drive to MOS, so the Riot Client only verifies it
  instead of downloading ~40 GB. Only reads from the source.

.EXAMPLE
  .\seed-valorant.ps1                     # finds "<drive>:\Riot Games\VALORANT" on the other Windows drives
  .\seed-valorant.ps1 -DryRun             # list what would be copied
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Target = (Join-Path $env:SystemDrive 'Riot Games\VALORANT'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

function Find-ValorantSources([string[]]$Roots) {
    if (-not $Roots) { $Roots = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }) }
    foreach ($r in $Roots) {
        if ($r.TrimEnd('\') -ieq $env:SystemDrive) { continue }
        $p = Join-Path $r 'Riot Games\VALORANT'
        if (Test-Path -LiteralPath (Join-Path $p 'live')) {
            [pscustomobject]@{ Path = $p; Updated = (Get-Item -LiteralPath (Join-Path $p 'live')).LastWriteTime }
        }
    }
}

function Invoke-Seed {
    $isMos = (Test-Path -LiteralPath (Join-Path $env:SystemDrive 'MOS\.mos-host'))
    if (-not $DryRun -and -not $isMos) { throw 'This copies into MOS and only runs there. Use -DryRun to preview elsewhere.' }
    if (-not $Source) {
        $c = @(Find-ValorantSources | Sort-Object Updated -Descending)
        if (-not $c.Count) { throw 'No "Riot Games\VALORANT" folder found on the other drives. Install VALORANT on MOS normally.' }
        $Source = $c[0].Path
        if ($c.Count -gt 1) { Write-Host ("Several copies found; using the newest: {0}" -f $Source) -ForegroundColor Yellow }
    }
    $src = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
    if ($src -ieq $Target.TrimEnd('\')) { throw 'Source and target are the same folder.' }
    $rcArgs = @($src, $Target, '/E', '/R:1', '/W:1', '/MT:8', '/NP', '/NDL', '/NFL')
    if ($DryRun) { $rcArgs += '/L' }
    Write-Host ("{0} {1} -> {2}" -f $(if ($DryRun) { 'Would copy' } else { 'Copying' }), $src, $Target)
    & robocopy.exe @rcArgs | Out-Host
    $code = $LASTEXITCODE
    if ($code -ge 8) { throw "robocopy failed ($code)." }
    if (-not $DryRun) { Write-Host 'Done. Install the Riot Client, choose this folder for VALORANT, and let it verify the files.' -ForegroundColor Green }
    $code
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-Seed | Out-Null }
