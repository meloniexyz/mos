#Requires -Version 5.1
<#
.SYNOPSIS
  Regenerates docs/TWEAKS.md from the tuning modules. Keeps the "Bench result" notes already written in the file.
#>
param([string]$OutFile = (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\TWEAKS.md'))

$ErrorActionPreference = 'Stop'
$tune = Join-Path (Split-Path $PSScriptRoot -Parent) 'usb\MOS\tune'
Import-Module (Join-Path $tune 'MosTune.psm1') -Force
Set-MosConfig @{ ModulesDir = (Join-Path $tune 'modules'); KeepListPath = (Join-Path $tune 'keep-list.psd1') }
$loaded = Import-MosTweaks
if ($loaded.Rejected.Count) { throw "Rejected tweaks: " + (($loaded.Rejected | ForEach-Object { "$($_.Id): $($_.Reason)" }) -join '; ') }

# keep bench notes written by hand: lines "| `id` | ... | note |" in the experimental table
$notes = @{}
if (Test-Path -LiteralPath $OutFile) {
    foreach ($line in Get-Content -LiteralPath $OutFile) {
        if ($line -match '^\| `(exp-[a-z0-9-]+)` \|.*\| ([^|]*) \|\s*$' -and $Matches[2].Trim() -and $Matches[2].Trim() -ne 'not tested yet') { $notes[$Matches[1]] = $Matches[2].Trim() }
    }
}

function Get-TargetText($t) {
    switch ($t.Type) {
        'Registry' { if ($t['Remove']) { "``$($t.Target)\$($t.Name)`` deleted" } else { "``$($t.Target)\$($t.Name)`` = $($t.Value)" } }
        'Service' { "service ``$($t.Target)`` -> $($t.Value)" }
        'ScheduledTask' { "task ``$($t.Target)`` -> $($t.Value)" }
        'PowerSetting' { "MOS plan setting ``$($t.Setting)`` = $($t.Value)" }
        'Appx' { "app ``$($t.Target)`` removed" }
        'OptionalFeature' { "feature ``$($t.Target)`` -> $($t.Value)" }
        'Bcd' { "boot ``$($t.Target)`` = $($t.Value)" }
        'NetAdapterProperty' { "wired adapter ``$($t.Target)`` = $($t.Value)" }
        'PnpRegistry' { "``$($t.InstancePattern)`` ``$($t.Name)`` = $($t.Value)" }
        'IniFile' { "``[$($t.Section)]`` in VALORANT settings, $(@($t.Settings.Keys).Count) keys" }
        'Script' { "script ``$($t.Script).ps1``" }
        default { $t.Type }
    }
}
function Esc([string]$s) { $s.Replace('|', '\|') }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# MOS tweaks')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Generated from `usb/MOS/tune/modules` by `tools/gen-tweaks-doc.ps1`. Do not edit the tables by hand, except the "Bench result" column of the experimental table.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('- **Apply** the standard profile: `C:\MOS\tune\tune.ps1 apply` (admin, MOS only).')
[void]$sb.AppendLine('- **Undo** anything: `tune.ps1 undo -Id <id>`, `tune.ps1 undo -Module <module>`, or `tune.ps1 undo` for everything. Each tweak restores the exact value it found.')
[void]$sb.AppendLine('- **Check** after Windows updates: `tune.ps1 check` lists what drifted.')
[void]$sb.AppendLine('- Apps are removed for the MOS user only; undo re-registers them. OneDrive undo reinstalls it with the setup in Windows. The NVIDIA App cannot be restored by undo (reinstall from nvidia.com).')
[void]$sb.AppendLine('')
[void]$sb.AppendLine(("{0} tweaks: {1} standard, {2} experimental." -f $loaded.Tweaks.Count, @($loaded.Tweaks | Where-Object { $_.Tier -eq 'standard' }).Count, @($loaded.Tweaks | Where-Object { $_.Tier -eq 'experimental' }).Count))

foreach ($group in ($loaded.Tweaks | Group-Object { $_.Module })) {
    $isExp = $group.Name -eq 'experimental'
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("## $($group.Name)")
    [void]$sb.AppendLine('')
    if ($isExp) {
        [void]$sb.AppendLine('Never applied by default. Apply a group by id, reboot, bench, and keep it only if the comparison shows a real gain (see INSTALL.md, step 9).')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Id | Changes | Why | Bench result |')
        [void]$sb.AppendLine('|----|---------|-----|--------------|')
    }
    else {
        [void]$sb.AppendLine('| Id | Changes | Why |')
        [void]$sb.AppendLine('|----|---------|-----|')
    }
    foreach ($t in $group.Group) {
        $row = "| ``$($t.Id)`` | $(Esc (Get-TargetText $t)) | $(Esc $t.Why) |"
        if ($isExp) { $row += " $(if ($notes.ContainsKey($t.Id)) { $notes[$t.Id] } else { 'not tested yet' }) |" }
        [void]$sb.AppendLine($row)
    }
}

$dir = Split-Path $OutFile -Parent
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
[IO.File]::WriteAllText($OutFile, $sb.ToString(), (New-Object Text.UTF8Encoding $false))
Write-Host "Wrote $OutFile ($($loaded.Tweaks.Count) tweaks)"
