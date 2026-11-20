#Requires -Version 5.1
<#
.SYNOPSIS
  Frame-time benchmarking for VALORANT with PresentMon (put PresentMon*.exe in bench\tools).

.EXAMPLE
  .\bench.ps1 capture -Label baseline -Seconds 120     # start it, then play a deathmatch (needs admin)
  .\bench.ps1 summary -Label baseline                  # print the latest "baseline" summary
  .\bench.ps1 compare -Label baseline, spectre-off     # first label is the reference
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][ValidateSet('capture', 'summary', 'compare')][string]$Command = 'summary',
    [string[]]$Label,
    [int]$Seconds = 120,
    [int]$WaitTimeout = 300,
    [string]$ProcessName = 'VALORANT-Win64-Shipping',
    [string]$PresentMon,
    [string]$ResultsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'results')
)
$ErrorActionPreference = 'Stop'

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

function Save-Summary([string]$CsvPath, [string]$RunLabel) {
    $s = Get-FrameStats (Get-FrameTimes $CsvPath)
    $s | Add-Member Label $RunLabel
    $s | Add-Member Date (Get-Date -Format o)
    $s | Add-Member File (Split-Path $CsvPath -Leaf)
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
    foreach ($m in 'AvgFps', 'Low1', 'Low01') {
        $vals = @($baseRuns | ForEach-Object { [double]$_.$m })
        $mean = ($vals | Measure-Object -Average).Average
        $noise = if ($vals.Count -ge 2 -and $mean) { (($vals | Measure-Object -Maximum).Maximum - ($vals | Measure-Object -Minimum).Minimum) / $mean } else { 0 }
        $threshold = [math]::Max($noise, $MinNoise)
        foreach ($l in $Labels | Select-Object -Skip 1) {
            $run = @($Summaries | Where-Object { $_.Label -eq $l })
            if (-not $run.Count) { Write-Warning "No runs labelled '$l'."; continue }
            $v = [double]$run[-1].$m
            $delta = ($v - [double]$ref.$m) / [double]$ref.$m
            $verdict = if ([math]::Abs($delta) -le $threshold) { 'within noise' } elseif ($delta -gt 0) { 'gain' } else { 'loss' }
            [pscustomobject]@{ Label = $l; Metric = $m; Reference = [double]$ref.$m; Value = $v; DeltaPct = [math]::Round($delta * 100, 1); NoisePct = [math]::Round($threshold * 100, 1); Verdict = $verdict }
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
            Write-Host "Recording $Seconds s. Keep playing."
            & $pm (New-PresentMonArgs $ProcessName $csv $Seconds) | Out-Null
            if (-not (Test-Path -LiteralPath $csv)) { throw "PresentMon wrote no file (run as administrator?)." }
            Save-Summary $csv $Label[0] | Format-List
        }
        'summary' {
            $all = Get-Summaries $ResultsDir
            if ($Label) { $all = @($all | Where-Object { $Label -contains $_.Label }) }
            $all | Select-Object Label, Date, Frames, AvgFps, Low1, Low01, P99Ms, StdevMs | Format-Table -AutoSize
        }
        'compare' {
            if (-not $Label -or $Label.Count -lt 2) { throw 'compare needs at least two labels: reference first.' }
            Compare-Bench (Get-Summaries $ResultsDir) $Label | Format-Table -AutoSize
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-Bench }
