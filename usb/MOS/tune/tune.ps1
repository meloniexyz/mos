#Requires -Version 5.1
<#
.SYNOPSIS
  MOS tuner. apply / undo change MOS (admin, MOS only); check is read-only and runs anywhere.

.EXAMPLE
  .\tune.ps1 check                         # what matches, what drifted
  .\tune.ps1 apply -DryRun                 # preview the standard profile
  .\tune.ps1 apply                         # apply all standard tweaks
  .\tune.ps1 apply -Id exp-spectre-*       # one experimental tweak (group)
  .\tune.ps1 undo -Module services         # restore one module
  .\tune.ps1 undo                          # restore everything MOS changed
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][ValidateSet('apply', 'undo', 'check')][string]$Command,
    [string[]]$Module,
    [string[]]$Id,
    [switch]$DryRun,
    [switch]$SkipVanguardCheck,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'MosTune.psm1') -Force

try {
    $run = Invoke-MosTune -Command $Command -Module $Module -Id $Id -DryRun:$DryRun -SkipVanguardCheck:$SkipVanguardCheck
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}

$colors = @{ applied = 'Green'; restored = 'Green'; ok = 'Green'; matches = 'DarkGreen'; unchanged = 'DarkGreen'
    'would-change' = 'Cyan'; 'would-restore' = 'Cyan'; 'not-applied' = 'Yellow'; drift = 'Yellow'; skipped = 'DarkYellow'
    unknown = 'DarkYellow'; failed = 'Red'; rejected = 'Red' }

$title = "MOS tuner: $Command" + $(if ($DryRun) { ' (dry run, nothing changed)' })
Write-Host ""
Write-Host $title -ForegroundColor White
foreach ($group in ($run.Results | Group-Object Module)) {
    Write-Host ""
    Write-Host ("[{0}]" -f $group.Name) -ForegroundColor White
    foreach ($r in $group.Group) {
        $c = if ($colors.ContainsKey($r.Status)) { $colors[$r.Status] } else { 'Gray' }
        Write-Host ("  {0,-13} {1,-34} {2}" -f $r.Status, $r.Id, $r.Detail) -ForegroundColor $c
    }
}

Write-Host ""
$counts = $run.Results | Group-Object Status | ForEach-Object { "{0} {1}" -f $_.Count, $_.Name }
Write-Host ("Summary: " + ($counts -join ', '))

if ($run.Vanguard.Count) {
    Write-Host ""
    Write-Host "Vanguard compatibility:" -ForegroundColor White
    foreach ($v in $run.Vanguard) {
        $c = switch ($v.Status) { 'PASS' { 'Green' } 'FAIL' { 'Red' } default { 'DarkYellow' } }
        Write-Host ("  {0,-8} {1,-26} {2}" -f $v.Status, $v.Item, $v.Detail) -ForegroundColor $c
    }
}
Write-Host ""
Write-Host "Log: $($run.LogPath)" -ForegroundColor DarkGray

if ($PassThru) { $run }
$bad = @($run.Results | Where-Object { $_.Status -in 'failed', 'rejected' }).Count + $run.VanguardFailures.Count
if ($bad) { exit 1 } else { exit 0 }
