#Requires -Version 5.1
<#
.SYNOPSIS
  Restart once into MOS. The boot default stays the daily Windows 10, so the next normal restart comes back here.
  Started (elevated) by the "Play VALORANT" desktop shortcut that install-switch.ps1 creates.
#>
[CmdletBinding()]
param([string]$Description = 'MOS', [switch]$NoRestart)

function Get-BcdEntries([string[]]$BcdText) {
    # splits `bcdedit /enum /v` output into entries with identifier + description
    $entries = @(); $cur = $null
    foreach ($line in $BcdText) {
        if ($line -match '^\s*identifier\s+(\{[0-9a-fA-F-]{36}\})') { if ($cur) { $entries += [pscustomobject]$cur }; $cur = @{ Identifier = $Matches[1].ToLower(); Description = $null } }
        elseif ($cur -and $line -match '^\s*description\s+(.*?)\s*$') { $cur.Description = $Matches[1] }
    }
    if ($cur) { $entries += [pscustomobject]$cur }
    $entries
}

function Find-MosBootEntry([string[]]$BcdText, [string]$Name = 'MOS') {
    $hits = @(Get-BcdEntries $BcdText | Where-Object { $_.Description -eq $Name })
    if ($hits.Count -eq 1) { return [pscustomobject]@{ Status = 'ok'; Entry = $hits[0]; Message = "Found $Name at $($hits[0].Identifier)" } }
    if (-not $hits.Count) { return [pscustomobject]@{ Status = 'missing'; Entry = $null; Message = "No boot entry named '$Name'. Is MOS installed? Its bootstrap renames its entry to '$Name'." } }
    [pscustomobject]@{ Status = 'ambiguous'; Entry = $null; Message = ("{0} boot entries are named '{1}': {2}. Rename the wrong one: bcdedit /set <id> description ""something else""" -f $hits.Count, $Name, (($hits | ForEach-Object { $_.Identifier }) -join ', ')) }
}

function Invoke-PlayValorant {
    $text = & bcdedit.exe /enum /v 2>&1
    if ($LASTEXITCODE) { Write-Host "bcdedit failed (run as administrator): $text" -ForegroundColor Red; Read-Host 'Press Enter to close'; return }
    $r = Find-MosBootEntry $text $Description
    if ($r.Status -ne 'ok') { Write-Host $r.Message -ForegroundColor Red; Read-Host 'Nothing changed. Press Enter to close'; return }
    & bcdedit.exe /bootsequence $r.Entry.Identifier | Out-Null
    if ($LASTEXITCODE) { Write-Host 'Could not set the one-time boot entry.' -ForegroundColor Red; Read-Host 'Press Enter to close'; return }
    Write-Host 'Restarting into MOS...' -ForegroundColor Green
    if (-not $NoRestart) { & shutdown.exe /r /t 0 }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-PlayValorant }
