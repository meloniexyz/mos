#Requires -Version 5.1
# MOS tuning engine: loads declarative tweaks, records prior state, applies / undoes / checks.
# Handlers (one per tweak Type) live in .\handlers and register themselves with Register-MosHandler.

$ErrorActionPreference = 'Stop'

$script:TuneRoot = $PSScriptRoot
$script:Handlers = @{}
$script:ScriptCache = @{}
$script:MosPlanGuid = '4d4f5300-0000-4000-8000-000000000001'   # "MOS" power plan

$script:Config = @{
    StatePath      = Join-Path $env:SystemDrive 'MOS\state\state.json'
    LogDir         = $null    # $null = C:\MOS\logs on MOS, %TEMP%\MOS-logs elsewhere
    HostMarkerFile = Join-Path $env:SystemDrive 'MOS\.mos-host'
    HostRegKey     = 'HKLM:\SOFTWARE\MOS'
    ModulesDir     = Join-Path $PSScriptRoot 'modules'
    KeepListPath   = Join-Path $PSScriptRoot 'keep-list.psd1'
    ScriptsDir     = Join-Path $PSScriptRoot 'scripts'
    VanguardCheck  = { $p = Join-Path (Split-Path $script:TuneRoot -Parent) 'vanguard-check.ps1'; if (Test-Path $p) { & $p -PassThru -Quiet } }
    IsAdmin        = { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
}

# Required fields per tweak Type (on top of Id, Tier, Type, Why).
$script:TypeFields = @{
    Registry           = @('Target', 'Name')
    Service            = @('Target', 'Value')
    ScheduledTask      = @('Target', 'Value')
    PowerSetting       = @('Scheme', 'Subgroup', 'Setting', 'Value')
    Appx               = @('Target')
    OptionalFeature    = @('Target', 'Value')
    Bcd                = @('Target')
    NetAdapterProperty = @('Target', 'Value')
    PnpRegistry        = @('Class', 'InstancePattern', 'SubKey', 'Name', 'Value', 'ValueType')
    IniFile            = @('Path', 'Section', 'Settings')
    Script             = @('Script')
}
$script:AllowedValues = @{
    Service         = @('Disabled', 'Manual', 'Automatic', 'AutomaticDelayed')
    ScheduledTask   = @('Disabled', 'Enabled')
    OptionalFeature = @('Disabled', 'Enabled')
}

# ---------------------------------------------------------------- config / helpers

function Get-MosConfig { $script:Config }

function Set-MosConfig {
    param([Parameter(Mandatory)][hashtable]$Values)
    foreach ($k in $Values.Keys) { $script:Config[$k] = $Values[$k] }
}

function Get-MosPlanGuid { $script:MosPlanGuid }

function ConvertTo-MosHashtable {
    param($InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in @($InputObject.Keys)) { $h[$k] = ConvertTo-MosHashtable $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-MosHashtable $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $list = @(foreach ($i in $InputObject) { ConvertTo-MosHashtable $i })
        return , $list
    }
    return $InputObject
}

# Stable JSON text for comparing two state values (sorted keys, no whitespace).
function ConvertTo-MosCanonical {
    param($InputObject)
    function Sort-Node($n) {
        if ($null -eq $n) { return $null }
        if ($n -is [System.Collections.IDictionary]) {
            $o = [ordered]@{}
            foreach ($k in (@($n.Keys) | Sort-Object)) { $o[[string]$k] = Sort-Node $n[$k] }
            return $o
        }
        if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) { return , @(foreach ($i in $n) { Sort-Node $i }) }
        return [string]$n
    }
    ConvertTo-Json -InputObject (Sort-Node (ConvertTo-MosHashtable $InputObject)) -Compress -Depth 20
}

function Split-MosTaskPath {
    param([string]$Target)
    $i = $Target.LastIndexOf('\')
    @{ Path = $Target.Substring(0, $i + 1); Name = $Target.Substring($i + 1) }
}

# ---------------------------------------------------------------- host guard

function Test-MosHost {
    $file = Test-Path -LiteralPath $script:Config.HostMarkerFile
    $reg = $false
    try { $reg = ((Get-ItemProperty -LiteralPath $script:Config.HostRegKey -ErrorAction Stop).Host -eq 1) } catch { $reg = $false }
    return ($file -and $reg)
}

# ---------------------------------------------------------------- handlers

function Register-MosHandler {
    param([Parameter(Mandatory)][string]$Type, [Parameter(Mandatory)][hashtable]$Handler, [string[]]$Fields)
    foreach ($k in 'Get', 'Set') { if (-not $Handler.ContainsKey($k)) { throw "Handler '$Type' is missing '$k'." } }
    $script:Handlers[$Type] = $Handler
    if ($PSBoundParameters.ContainsKey('Fields')) { $script:TypeFields[$Type] = @($Fields) }   # new types (used by tests)
}

function Get-MosHandler {
    param([string]$Type)
    if (-not $script:Handlers.ContainsKey($Type)) { throw "No handler registered for type '$Type'." }
    $script:Handlers[$Type]
}

function Get-MosScript {
    param([string]$Name)
    if (-not $script:ScriptCache.ContainsKey($Name)) {
        $path = Join-Path $script:Config.ScriptsDir "$Name.ps1"
        if (-not (Test-Path -LiteralPath $path)) { throw "Script tweak '$Name' not found at $path." }
        # Load into its own dynamic module: the script's helper functions and variables stay reachable
        # from the scriptblocks it returns (a plain '& $path' would drop them when the script exits).
        $mod = New-Module -Name "MosScript_$Name" -ArgumentList $path -ScriptBlock {
            param($p)
            $script:MosImpl = . $p
            Export-ModuleMember -Function @()
        }
        $impl = & $mod { $script:MosImpl }
        if ($impl -isnot [hashtable] -or -not $impl.Get -or -not $impl.Set) { throw "Script '$Name' must return a hashtable with Get and Set." }
        $script:ScriptCache[$Name] = $impl
    }
    $script:ScriptCache[$Name]
}

function Get-MosDesired {
    param($Handler, $Tweak, $Current)
    if ($Handler.Desired) { return (& $Handler.Desired $Tweak $Current) }
    # note: index access - $hashtable.Remove would return the Hashtable.Remove method, which is always truthy
    if ($Tweak['Remove']) { return @{ Absent = $true } }
    return @{ Absent = $false; Value = $Tweak.Value }
}

function Test-MosEqual {
    param($Handler, $Current, $Desired, $Tweak)
    if ($Handler.Equal) { return [bool](& $Handler.Equal $Current $Desired $Tweak) }
    if ($Current.Absent -or $Desired.Absent) { return ([bool]$Current.Absent -eq [bool]$Desired.Absent) }
    return ((ConvertTo-MosCanonical $Current.Value) -eq (ConvertTo-MosCanonical $Desired.Value))
}

function Format-MosValue {
    param($v)
    if ($null -eq $v) { return '<none>' }
    if ($v.Absent) { return '<absent>' }
    $x = if ($v -is [System.Collections.IDictionary] -and $v.Contains('Value')) { $v.Value } else { $v }
    $s = ConvertTo-MosCanonical $x
    if ($s.Length -gt 160) { $s = $s.Substring(0, 157) + '...' }
    $s
}

# ---------------------------------------------------------------- tweak loading

function Test-MosTweakSchema {
    param([hashtable]$Tweak)
    foreach ($f in 'Id', 'Tier', 'Type', 'Why') {
        if (-not $Tweak.ContainsKey($f) -or [string]::IsNullOrWhiteSpace([string]$Tweak[$f])) { return "missing field '$f'" }
    }
    if ($Tweak.Id -notmatch '^[a-z0-9][a-z0-9-]*$') { return "invalid id '$($Tweak.Id)' (use lowercase letters, digits and dashes)" }
    if ($Tweak.Tier -notin 'standard', 'experimental') { return "tier must be 'standard' or 'experimental'" }
    if (-not $script:TypeFields.ContainsKey($Tweak.Type)) { return "unknown type '$($Tweak.Type)'" }
    foreach ($f in $script:TypeFields[$Tweak.Type]) { if (-not $Tweak.ContainsKey($f)) { return "type $($Tweak.Type) needs field '$f'" } }
    if ($Tweak.Type -in 'Registry', 'Bcd' -and -not ($Tweak.ContainsKey('Value') -or $Tweak['Remove'])) { return "needs 'Value' or 'Remove = `$true'" }
    if ($Tweak.Type -eq 'Registry') {
        if ($Tweak.Target -notmatch '^(HKLM|HKCU):\\') { return "registry target must start with HKLM:\ or HKCU:\" }
        if ($Tweak.ContainsKey('Value') -and -not $Tweak.ValueType) { return "needs 'ValueType'" }
    }
    if ($script:AllowedValues.ContainsKey($Tweak.Type) -and $Tweak.Value -notin $script:AllowedValues[$Tweak.Type]) {
        return "value '$($Tweak.Value)' not allowed for $($Tweak.Type) (use $($script:AllowedValues[$Tweak.Type] -join ', '))"
    }
    return $null
}

function Test-MosKeepList {
    param([hashtable]$Tweak, [hashtable]$KeepList)
    $services = @($KeepList.Services)
    switch ($Tweak.Type) {
        'Service' {
            if ($services -contains $Tweak.Target) { return "keep-list: service '$($Tweak.Target)' is protected" }
        }
        { $_ -in 'Registry', 'PnpRegistry' } {
            if (@($KeepList.RegistryValueNames) -contains $Tweak.Name) { return "keep-list: registry value '$($Tweak.Name)' is protected" }
            if ($Tweak.Type -eq 'Registry') {
                foreach ($p in @($KeepList.RegistryKeyPatterns)) { if ($Tweak.Target -like $p) { return "keep-list: registry key '$($Tweak.Target)' is protected ($p)" } }
                if ($Tweak.Target -match '\\Services\\([^\\]+)' -and $services -contains $Matches[1]) { return "keep-list: service '$($Matches[1])' is protected (registry)" }
            }
        }
        'Bcd' {
            if (@($KeepList.BcdSettings) -contains $Tweak.Target) { return "keep-list: boot setting '$($Tweak.Target)' is protected" }
        }
        'Appx' {
            foreach ($p in @($KeepList.AppxPatterns)) { if ($Tweak.Target -like $p) { return "keep-list: app '$($Tweak.Target)' is protected ($p)" } }
        }
        'OptionalFeature' {
            if (@($KeepList.OptionalFeatures) -contains $Tweak.Target) { return "keep-list: feature '$($Tweak.Target)' is protected" }
        }
        'ScheduledTask' {
            foreach ($p in @($KeepList.ScheduledTaskPatterns)) { if ($Tweak.Target -like $p) { return "keep-list: task '$($Tweak.Target)' is protected ($p)" } }
        }
    }
    return $null
}

function Import-MosTweaks {
    param(
        [string]$ModulesDir = $script:Config.ModulesDir,
        [string]$KeepListPath = $script:Config.KeepListPath
    )
    $keep = Import-PowerShellDataFile -LiteralPath $KeepListPath
    $tweaks = New-Object System.Collections.ArrayList
    $rejected = New-Object System.Collections.ArrayList
    $seen = @{}
    $order = 0
    foreach ($f in (Get-ChildItem -LiteralPath $ModulesDir -Filter *.psd1 | Sort-Object Name)) {
        try { $data = Import-PowerShellDataFile -LiteralPath $f.FullName -ErrorAction Stop }
        catch { [void]$rejected.Add([pscustomobject]@{ Id = "<$($f.Name)>"; Module = $f.BaseName; Reason = "cannot parse: $($_.Exception.Message)" }); continue }
        $module = if ($data['Module']) { [string]$data['Module'] } else { $f.BaseName -replace '^\d+-', '' }
        foreach ($raw in @($data['Tweaks'])) {
            if ($raw -isnot [System.Collections.IDictionary]) { continue }
            $t = ConvertTo-MosHashtable $raw
            $t.Module = $module
            $problem = Test-MosTweakSchema $t
            if (-not $problem -and $seen.ContainsKey($t.Id)) { $problem = "duplicate id (also in module '$($seen[$t.Id])')" }
            if (-not $problem) { $problem = Test-MosKeepList -Tweak $t -KeepList $keep }
            if ($problem) {
                [void]$rejected.Add([pscustomobject]@{ Id = $t.Id; Module = $module; Reason = $problem })
            }
            else {
                $t.Order = $order++
                $seen[$t.Id] = $module
                [void]$tweaks.Add($t)
            }
        }
    }
    [pscustomobject]@{ Tweaks = @($tweaks); Rejected = @($rejected) }
}

# ---------------------------------------------------------------- state store

function Get-MosStateBackupDir { Join-Path (Split-Path $script:Config.StatePath -Parent) 'backup' }

function Read-MosState {
    $p = $script:Config.StatePath
    if (-not (Test-Path -LiteralPath $p)) { return @{} }
    try {
        $text = [IO.File]::ReadAllText($p)
        if ([string]::IsNullOrWhiteSpace($text)) { return @{} }
        $h = ConvertTo-MosHashtable ($text | ConvertFrom-Json)
        if ($h -isnot [hashtable]) { throw 'state root is not an object' }
        return $h
    }
    catch {
        $bad = $_.Exception.Message
        $latest = Get-ChildItem -LiteralPath (Get-MosStateBackupDir) -Filter 'state-*.json' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $latest) { throw "State file '$p' is unreadable ($bad) and no backup exists." }
        Write-Warning "State file unreadable ($bad). Recovered from backup $($latest.Name)."
        return (ConvertTo-MosHashtable ([IO.File]::ReadAllText($latest.FullName) | ConvertFrom-Json))
    }
}

function Write-MosState {
    param([Parameter(Mandatory)][hashtable]$State)
    $p = $script:Config.StatePath
    $dir = Split-Path $p -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = ConvertTo-Json -InputObject $State -Depth 20
    $tmp = "$p.tmp"
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $p) { [IO.File]::Replace($tmp, $p, [NullString]::Value) } else { [IO.File]::Move($tmp, $p) }
}

function Backup-MosState {
    $p = $script:Config.StatePath
    if (-not (Test-Path -LiteralPath $p)) { return }
    $dir = Get-MosStateBackupDir
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $p -Destination (Join-Path $dir ("state-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff')))
    Get-ChildItem -LiteralPath $dir -Filter 'state-*.json' | Sort-Object Name -Descending | Select-Object -Skip 20 | Remove-Item -Force
}

# ---------------------------------------------------------------- logging

$script:LogPath = $null

function Start-MosLog {
    param([string]$Command)
    $dir = $script:Config.LogDir
    if (-not $dir) { $dir = if (Test-MosHost) { Join-Path $env:SystemDrive 'MOS\logs' } else { Join-Path $env:TEMP 'MOS-logs' } }
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $script:LogPath = Join-Path $dir ("{0}-{1}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Command)
    Write-MosLog "MOS tuner $Command on $env:COMPUTERNAME"
    $script:LogPath
}

function Write-MosLog {
    param([string]$Message)
    if ($script:LogPath) { Add-Content -LiteralPath $script:LogPath -Value ("{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -Encoding UTF8 }
}

# ---------------------------------------------------------------- selection

function Test-MosIdMatch {
    param([string]$TweakId, [string[]]$Id)
    foreach ($p in $Id) { if ($TweakId -like $p) { return $true } }
    return $false
}

function Select-MosTweaks {
    param($Tweaks, [hashtable]$State, [string]$Command, [string[]]$Module, [string[]]$Id)
    $byId = @{}
    foreach ($t in $Tweaks) { $byId[$t.Id] = $t }

    $pool = New-Object System.Collections.ArrayList
    if ($Command -eq 'undo') {
        foreach ($k in $State.Keys) {
            $t = if ($byId.ContainsKey($k)) { $byId[$k] } else { $State[$k].tweak }
            if ($t) { [void]$pool.Add($t) }
        }
    }
    else {
        foreach ($t in $Tweaks) { [void]$pool.Add($t) }
        if ($Command -eq 'check') {
            # tweaks recorded in state but no longer defined in any module
            foreach ($k in $State.Keys) { if (-not $byId.ContainsKey($k) -and $State[$k].tweak) { [void]$pool.Add($State[$k].tweak) } }
        }
    }

    $out = foreach ($t in $pool) {
        if ($Module -and $t.Module -notin $Module) { continue }
        $idHit = $Id -and (Test-MosIdMatch $t.Id $Id)
        if ($Id -and -not $idHit) { continue }
        if ($Command -eq 'apply' -and $t.Tier -eq 'experimental' -and -not $idHit) { continue }
        if ($Command -eq 'check' -and $t.Tier -eq 'experimental' -and -not $idHit -and -not $State.ContainsKey($t.Id)) { continue }
        $t
    }
    if ($Command -eq 'undo') {
        # undo newest first so dependent tweaks (e.g. power settings, then the plan) unwind in reverse
        return @($out | Sort-Object @{ Expression = { [string]$State[$_.Id].appliedAt } } -Descending)
    }
    return @($out)
}

# ---------------------------------------------------------------- runner

function New-MosResult {
    param($Tweak, [string]$Status, [string]$Detail)
    [pscustomobject]@{ Id = $Tweak.Id; Module = $Tweak.Module; Tier = $Tweak.Tier; Status = $Status; Detail = $Detail }
}

function Invoke-MosTune {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('apply', 'undo', 'check')][string]$Command,
        [string[]]$Module,
        [string[]]$Id,
        [switch]$DryRun,
        [switch]$SkipVanguardCheck
    )
    $changing = ($Command -in 'apply', 'undo') -and -not $DryRun
    if ($changing) {
        if (-not (Test-MosHost)) { throw "MOS tuner: '$Command' only runs on MOS (host marker not found). Use 'check' or -DryRun on other systems." }
        if (-not (& $script:Config.IsAdmin)) { throw "MOS tuner: '$Command' needs administrator rights. Rerun from an elevated PowerShell." }
    }

    $log = Start-MosLog ($Command + $(if ($DryRun) { '-dryrun' }))
    $loaded = Import-MosTweaks
    foreach ($r in $loaded.Rejected) { Write-MosLog "REJECTED $($r.Id) [$($r.Module)]: $($r.Reason)" }

    $state = Read-MosState
    if ($changing) { Backup-MosState }
    $selected = Select-MosTweaks -Tweaks $loaded.Tweaks -State $state -Command $Command -Module $Module -Id $Id

    $results = New-Object System.Collections.ArrayList
    foreach ($r in $loaded.Rejected) { [void]$results.Add([pscustomobject]@{ Id = $r.Id; Module = $r.Module; Tier = ''; Status = 'rejected'; Detail = $r.Reason }) }

    foreach ($t in $selected) {
        try {
            $h = Get-MosHandler $t.Type
            switch ($Command) {
                'apply' {
                    $cur = & $h.Get $t
                    $des = Get-MosDesired $h $t $cur
                    if ($des.Skip) { $res = New-MosResult $t 'skipped' $des.Skip; break }
                    if (Test-MosEqual $h $cur $des $t) {
                        if (-not $DryRun -and -not $state.ContainsKey($t.Id)) {
                            $state[$t.Id] = @{ before = $cur; appliedAt = (Get-Date).ToString('o'); tweak = $t }
                            Write-MosState $state
                        }
                        $res = New-MosResult $t 'unchanged' 'already at the MOS value'
                        break
                    }
                    if ($DryRun) { $res = New-MosResult $t 'would-change' ("{0} -> {1}" -f (Format-MosValue $cur), (Format-MosValue $des)); break }
                    if (-not $state.ContainsKey($t.Id)) {
                        $state[$t.Id] = @{ before = $cur; appliedAt = (Get-Date).ToString('o'); tweak = $t }
                        Write-MosState $state   # record before changing anything
                    }
                    & $h.Set $t $des
                    $after = & $h.Get $t
                    if (Test-MosEqual $h $after $des $t) { $res = New-MosResult $t 'applied' ("{0} -> {1}" -f (Format-MosValue $cur), (Format-MosValue $des)) }
                    else { $res = New-MosResult $t 'failed' ("set ran but value is {0}" -f (Format-MosValue $after)) }
                }
                'undo' {
                    $entry = $state[$t.Id]
                    $before = $entry.before
                    if ($DryRun) { $res = New-MosResult $t 'would-restore' ("-> {0}" -f (Format-MosValue $before)); break }
                    & $h.Set $t $before
                    $after = & $h.Get $t
                    if (Test-MosEqual $h $after $before $t) {
                        $state.Remove($t.Id)
                        Write-MosState $state
                        $res = New-MosResult $t 'restored' ("-> {0}" -f (Format-MosValue $before))
                    }
                    else { $res = New-MosResult $t 'failed' ("restore ran but value is {0}" -f (Format-MosValue $after)) }
                }
                'check' {
                    $cur = & $h.Get $t
                    $des = Get-MosDesired $h $t $cur
                    $inState = $state.ContainsKey($t.Id)
                    if ($des.Skip) { $res = New-MosResult $t 'skipped' $des.Skip; break }
                    $eq = Test-MosEqual $h $cur $des $t
                    $status = if ($inState) { if ($eq) { 'ok' } else { 'drift' } } else { if ($eq) { 'matches' } else { 'not-applied' } }
                    $res = New-MosResult $t $status ("now {0}, MOS value {1}" -f (Format-MosValue $cur), (Format-MosValue $des))
                }
            }
        }
        catch {
            $res = New-MosResult $t $(if ($Command -eq 'check' -or $DryRun) { 'unknown' } else { 'failed' }) $_.Exception.Message
        }
        Write-MosLog ("{0,-13} {1} [{2}] {3}" -f $res.Status.ToUpper(), $res.Id, $res.Module, $res.Detail)
        [void]$results.Add($res)
    }

    $vanguard = @()
    if ($Command -eq 'apply' -and -not $DryRun -and -not $SkipVanguardCheck -and $script:Config.VanguardCheck) {
        try { $vanguard = @(& $script:Config.VanguardCheck) }
        catch { $vanguard = @([pscustomobject]@{ Item = 'vanguard-check'; Status = 'FAIL'; Detail = $_.Exception.Message }) }
        foreach ($v in $vanguard) { Write-MosLog ("VANGUARD {0,-6} {1}: {2}" -f $v.Status, $v.Item, $v.Detail) }
    }

    Write-MosLog ("Done. Log: {0}" -f $log)
    [pscustomobject]@{
        Command  = $Command
        DryRun   = [bool]$DryRun
        Results  = @($results)
        Vanguard = @($vanguard)
        VanguardFailures = @($vanguard | Where-Object { $_.Status -eq 'FAIL' })
        LogPath  = $log
    }
}

# Handlers register themselves on import.
foreach ($h in (Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'handlers') -Filter *.ps1 -ErrorAction SilentlyContinue)) { . $h.FullName }

Export-ModuleMember -Function Get-MosConfig, Set-MosConfig, Get-MosPlanGuid, ConvertTo-MosHashtable, ConvertTo-MosCanonical, `
    Split-MosTaskPath, Test-MosHost, Register-MosHandler, Get-MosHandler, Get-MosScript, Test-MosTweakSchema, Test-MosKeepList, `
    Import-MosTweaks, Read-MosState, Write-MosState, Backup-MosState, Select-MosTweaks, Invoke-MosTune, Format-MosValue
