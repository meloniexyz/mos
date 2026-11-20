#Requires -Version 5.1
<#
.SYNOPSIS
  Frame-time benchmarking for VALORANT with PresentMon (put PresentMon*.exe in bench\tools).

.EXAMPLE
  .\bench.ps1 capture -Label baseline -Seconds 120     # start it, then play a deathmatch (needs admin)
  .\bench.ps1 summary -Label baseline                  # print the latest "baseline" summary
  .\bench.ps1 compare -Label baseline, spectre-off     # first label is the reference
  .\bench.ps1 capture -Label irq-base -WithCounters    # also sample interrupt/DPC load every 5 s
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('capture', 'summary', 'compare')][string]$Command = 'summary',
    [string[]]$Label,
    [int]$Seconds = 120,
    [switch]$WithCounters,
    [int]$CounterInterval = 5,
    [int]$WaitTimeout = 300,
    [string]$ProcessName = 'VALORANT-Win64-Shipping',
    [string]$PresentMon,
    [string]$ResultsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'results')
)
$ErrorActionPreference = 'Stop'

# The doctor's readers give the environment snapshot (one code path for "what state is this PC in").
$script:BenchDoctor = Join-Path (Split-Path $PSScriptRoot -Parent) 'doctor.ps1'
if (Test-Path -LiteralPath $script:BenchDoctor) { . $script:BenchDoctor }
$script:BenchStatePath = Join-Path $env:SystemDrive 'MOS\state\state.json'

function Get-BenchEnv {
    function Try-Read([string]$Reader) { if (Get-Command $Reader -ErrorAction SilentlyContinue) { try { & $Reader } catch { $null } } else { $null } }
    $ram = @(Try-Read 'Get-DocRam')
    $display = Try-Read 'Get-DocDisplay'
    $plan = Try-Read 'Get-DocPowerPlan'
    $driver = Try-Read 'Get-DocDriverAge'
    $pending = Try-Read 'Get-DocPendingReboot'
    $exp = @()
    if (Test-Path -LiteralPath $script:BenchStatePath) {
        try {
            $state = Get-Content -LiteralPath $script:BenchStatePath -Raw | ConvertFrom-Json
            $exp = @($state.PSObject.Properties | Where-Object { $_.Value.tweak.Tier -eq 'experimental' } | ForEach-Object { $_.Name } | Sort-Object)
        }
        catch { }
    }
    [pscustomobject][ordered]@{
        RamMts              = $(if ($ram.Count) { ($ram | Measure-Object Configured -Minimum).Minimum } else { $null })
        RefreshHz           = $(if ($display) { $display.Current } else { $null })
        PowerPlan           = $(if ($plan) { $plan.Guid } else { $null })
        GpuDriver           = $(if ($driver) { $driver.Version } else { $null })
        ExperimentalApplied = $exp
        PendingRestart      = [bool]$pending
    }
}

# Differences that make two runs not comparable (Critical) vs. expected ones (Info: the experiments under test).
function Get-BenchEnvDiff($Ref, $Run) {
    $out = [pscustomobject]@{ Missing = $false; Critical = @(); Info = @() }
    if (-not $Ref -or -not $Run) { $out.Missing = $true; return $out }
    $crit = @()
    foreach ($f in 'RamMts', 'PowerPlan', 'GpuDriver', 'PendingRestart') {
        if ("$($Ref.$f)" -ne "$($Run.$f)") { $crit += "$f $($Ref.$f) -> $($Run.$f)" }
    }
    if ($Ref.RefreshHz -and $Run.RefreshHz -and [math]::Abs([double]$Ref.RefreshHz - [double]$Run.RefreshHz) -gt 2) { $crit += "RefreshHz $($Ref.RefreshHz) -> $($Run.RefreshHz)" }
    $a = @($Ref.ExperimentalApplied) -join ','; $b = @($Run.ExperimentalApplied) -join ','
    $out.Critical = $crit
    if ($a -ne $b) { $out.Info = @("experiments [$a] -> [$b]") }
    $out
}

function Find-PresentMon([string]$Explicit) {
    if ($Explicit) { if (Test-Path -LiteralPath $Explicit) { return $Explicit } else { throw "PresentMon not found at $Explicit" } }
    $p = Get-ChildItem (Join-Path $PSScriptRoot 'tools') -Filter 'PresentMon*.exe' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $p) { throw 'PresentMon not found. Download the console release from github.com/GameTechDev/PresentMon/releases and put it in bench\tools.' }
    $p.FullName
}

function New-PresentMonArgs([string]$Process, [string]$OutFile, [int]$Duration) {
    @('--process_name', "$Process.exe", '--output_file', $OutFile, '--timed', [string]$Duration, '--terminate_after_timed', '--stop_existing_session')
}

function Wait-ForProcess([string]$Name, [int]$TimeoutSeconds, [int]$PollSeconds = 2) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Get-Process -Name $Name -ErrorAction SilentlyContinue) { return $true }
        Start-Sleep -Seconds $PollSeconds
    }
    $false
}

# Low-rate system counters in a separate process (Start-Job) so PresentMon's run isn't disturbed.
function Start-CounterSampler([string]$OutCsv, [int]$Interval = 5) {
    Start-Job -ArgumentList $OutCsv, $Interval -ScriptBlock {
        param($out, $interval)
        $inv = [Globalization.CultureInfo]::InvariantCulture
        'time,intPct,dpcPct,busiestCore' | Set-Content -LiteralPath $out -Encoding ASCII
        $ctr = '\Processor(_Total)\% Interrupt Time', '\Processor(_Total)\% DPC Time', '\Processor(*)\% Processor Time'
        while ($true) {
            $s = (Get-Counter $ctr -SampleInterval $interval -MaxSamples 1 -ErrorAction SilentlyContinue).CounterSamples
            if (-not $s) { continue }
            $int = ($s | Where-Object { $_.Path -like '*_total)\% interrupt time' }).CookedValue
            $dpc = ($s | Where-Object { $_.Path -like '*_total)\% dpc time' }).CookedValue
            $busy = ($s | Where-Object { $_.Path -like '*\% processor time' -and $_.InstanceName -ne '_total' } | Measure-Object CookedValue -Maximum).Maximum
            ('{0},{1},{2},{3}' -f (Get-Date -Format 'HH:mm:ss'), ([double]$int).ToString('0.00', $inv), ([double]$dpc).ToString('0.00', $inv), ([double]$busy).ToString('0.00', $inv)) |
                Add-Content -LiteralPath $out -Encoding ASCII
        }
    }
}

function Stop-CounterSampler($Job) {
    if ($Job) { Stop-Job $Job -ErrorAction SilentlyContinue; Remove-Job $Job -Force -ErrorAction SilentlyContinue }
}

function Get-CounterStats([string]$CountersCsv) {
    $rows = @(Import-Csv -LiteralPath $CountersCsv)
    if (-not $rows.Count) { return $null }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $out = [ordered]@{}
    foreach ($pair in @(@('intPct', 'IntPct'), @('dpcPct', 'DpcPct'), @('busiestCore', 'BusiestCore'))) {
        $v = [double[]]@($rows | ForEach-Object { [double]::Parse($_.($pair[0]), $inv) } | Sort-Object)
        $out["$($pair[1])Med"] = [math]::Round((Get-Percentile $v 0.5), 2)
        $out["$($pair[1])P90"] = [math]::Round((Get-Percentile $v 0.9), 2)
    }
    $out['CounterSamples'] = $rows.Count
    $out
}

function Get-FrameTimes([string]$CsvPath) {
    $rows = Import-Csv -LiteralPath $CsvPath
    if (-not $rows) { throw "No frames in $CsvPath" }
    $cols = $rows[0].PSObject.Properties.Name
    $col = @('MsBetweenPresents', 'FrameTime', 'msBetweenPresents') | Where-Object { $cols -contains $_ } | Select-Object -First 1
    if (-not $col) { throw "No frame-time column in $CsvPath (have: $($cols -join ', '))" }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    , @($rows | ForEach-Object { $v = 0.0; if ([double]::TryParse($_.$col, [Globalization.NumberStyles]::Float, $inv, [ref]$v) -and $v -gt 0) { $v } })
}

function Get-Percentile([double[]]$Sorted, [double]$P) {
    $i = [math]::Ceiling($P * $Sorted.Count) - 1
    $Sorted[[math]::Max(0, [math]::Min($Sorted.Count - 1, $i))]
}

function Get-FrameStats([double[]]$FrameTimes) {
    if (-not $FrameTimes.Count) { throw 'No frame times.' }
    $sorted = [double[]]($FrameTimes | Sort-Object)
    $sum = 0.0; foreach ($f in $FrameTimes) { $sum += $f }
    $mean = $sum / $FrameTimes.Count
    $var = 0.0; foreach ($f in $FrameTimes) { $var += ($f - $mean) * ($f - $mean) }
    $p50 = Get-Percentile $sorted 0.50; $p99 = Get-Percentile $sorted 0.99
    # "1% low" = fps of the average of the slowest 1% of frames (same for 0.1%); stricter than a plain percentile
    function Get-WorstAvg([double]$Share) {
        $n = [math]::Max(1, [math]::Floor($sorted.Count * $Share))
        $s = 0.0; for ($i = $sorted.Count - $n; $i -lt $sorted.Count; $i++) { $s += $sorted[$i] }
        $s / $n
    }
    [pscustomobject]@{
        Frames  = $FrameTimes.Count
        Seconds = [math]::Round($sum / 1000, 1)
        AvgFps  = [math]::Round(1000 / $mean, 1)
        Low1    = [math]::Round(1000 / (Get-WorstAvg 0.01), 1)
        Low01   = [math]::Round(1000 / (Get-WorstAvg 0.001), 1)
        P50Ms   = [math]::Round($p50, 3)
        P99Ms   = [math]::Round($p99, 3)
        StdevMs = [math]::Round([math]::Sqrt($var / $FrameTimes.Count), 3)
    }
}

function Save-Summary([string]$CsvPath, [string]$RunLabel, $EnvSnapshot = $null) {
    $s = Get-FrameStats (Get-FrameTimes $CsvPath)
    $s | Add-Member Label $RunLabel
    $s | Add-Member Date (Get-Date -Format o)
    $s | Add-Member File (Split-Path $CsvPath -Leaf)
    if ($EnvSnapshot) { $s | Add-Member Env $EnvSnapshot }
    $countersCsv = [IO.Path]::ChangeExtension($CsvPath, '.counters.csv')
    if (Test-Path -LiteralPath $countersCsv) {
        $c = Get-CounterStats $countersCsv
        if ($c) { foreach ($k in $c.Keys) { $s | Add-Member $k $c[$k] } }
    }
    $out = [IO.Path]::ChangeExtension($CsvPath, '.summary.json')
    $s | ConvertTo-Json | Set-Content -LiteralPath $out -Encoding UTF8
    $s
}

function Get-Summaries([string]$Dir) {
    @(Get-ChildItem -LiteralPath $Dir -Filter '*.summary.json' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
}

function Compare-Bench([object[]]$Summaries, [string[]]$Labels, [double]$MinNoise = 0.02) {
    $base = $Labels[0]
    $baseRuns = @($Summaries | Where-Object { $_.Label -eq $base })
    if (-not $baseRuns.Count) { throw "No runs labelled '$base'." }
    $ref = $baseRuns[-1]
    foreach ($l in $Labels | Select-Object -Skip 1) {
        $run = @($Summaries | Where-Object { $_.Label -eq $l }) | Select-Object -Last 1
        if (-not $run) { continue }
        $d = Get-BenchEnvDiff $(if ($ref.PSObject.Properties['Env']) { $ref.Env }) $(if ($run.PSObject.Properties['Env']) { $run.Env })
        if ($d.Missing) { Write-Host "Note: '$base' or '$l' has no environment snapshot; can't check that conditions matched." -ForegroundColor DarkYellow }
        elseif ($d.Critical.Count) { Write-Warning ("'$l' was recorded under different conditions than '$base' - results are NOT comparable: " + ($d.Critical -join '; ')) }
        foreach ($i in $d.Info) { Write-Host "Info '$l': $i" -ForegroundColor DarkGray }
    }
    # frame metrics: higher is better. counter metrics (only when both runs have them): lower is better.
    $metrics = @(@('AvgFps', $true), @('Low1', $true), @('Low01', $true), @('IntPctMed', $false), @('DpcPctMed', $false))
    foreach ($pair in $metrics) {
        $m = $pair[0]; $higherBetter = $pair[1]
        if (-not $ref.PSObject.Properties[$m]) { continue }
        $vals = @($baseRuns | Where-Object { $_.PSObject.Properties[$m] } | ForEach-Object { [double]$_.$m })
        $mean = ($vals | Measure-Object -Average).Average
        $noise = if ($vals.Count -ge 2 -and $mean) { (($vals | Measure-Object -Maximum).Maximum - ($vals | Measure-Object -Minimum).Minimum) / $mean } else { 0 }
        $threshold = [math]::Max($noise, $MinNoise)
        foreach ($l in $Labels | Select-Object -Skip 1) {
            $run = @($Summaries | Where-Object { $_.Label -eq $l })
            if (-not $run.Count) { Write-Warning "No runs labelled '$l'."; continue }
            if (-not $run[-1].PSObject.Properties[$m]) { continue }   # runs without counters: frame metrics only
            $v = [double]$run[-1].$m
            $r = [double]$ref.$m
            $delta = ($v - $r) / [math]::Max([math]::Abs($r), 0.05)   # floor avoids dividing by ~0 % interrupt time
            $better = if ($higherBetter) { $delta } else { -$delta }
            $verdict = if ([math]::Abs($delta) -le $threshold) { 'within noise' } elseif ($better -gt 0) { 'gain' } else { 'loss' }
            [pscustomobject]@{ Label = $l; Metric = $m; Reference = $r; Value = $v; DeltaPct = [math]::Round($delta * 100, 1); NoisePct = [math]::Round($threshold * 100, 1); Verdict = $verdict }
        }
    }
}

function Invoke-Bench {
    switch ($Command) {
        'capture' {
            if (-not $Label) { throw 'Give the run a -Label, for example: -Label baseline' }
            $pm = Find-PresentMon $PresentMon
            New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
            $csv = Join-Path $ResultsDir ("{0}-{1}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Label[0])
            Write-Host "Waiting for $ProcessName (start a deathmatch)..."
            if (-not (Wait-ForProcess $ProcessName $WaitTimeout)) { throw "$ProcessName did not start within $WaitTimeout s." }
            $envSnap = Get-BenchEnv
            if ($envSnap.PendingRestart) { Write-Warning 'A restart is pending: some tweaks may not be active in this run.' }
            Write-Host "Recording $Seconds s. Keep playing."
            $sampler = $null
            if ($WithCounters) { $sampler = Start-CounterSampler ([IO.Path]::ChangeExtension($csv, '.counters.csv')) $CounterInterval }
            try { & $pm (New-PresentMonArgs $ProcessName $csv $Seconds) | Out-Null }
            finally { Stop-CounterSampler $sampler }
            if (-not (Test-Path -LiteralPath $csv)) { throw "PresentMon wrote no file (run as administrator?)." }
            Save-Summary $csv $Label[0] $envSnap | Format-List
        }
        'summary' {
            $all = Get-Summaries $ResultsDir
            if ($Label) { $all = @($all | Where-Object { $Label -contains $_.Label }) }
            $all | Select-Object Label, Date, Frames, AvgFps, Low1, Low01, P99Ms, StdevMs, IntPctMed, DpcPctMed, BusiestCoreMed | Format-Table -AutoSize
        }
        'compare' {
            if (-not $Label -or $Label.Count -lt 2) { throw 'compare needs at least two labels: reference first.' }
            Compare-Bench (Get-Summaries $ResultsDir) $Label | Format-Table -AutoSize
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-Bench }
