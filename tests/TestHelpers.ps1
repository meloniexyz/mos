# Shared setup for tuner tests: sandboxed config + an in-memory "Fake" tweak type.
$script:RepoRoot = Split-Path $PSScriptRoot -Parent
$script:TuneDir = Join-Path $script:RepoRoot 'usb\MOS\tune'

function Initialize-MosTestEnv {
    param([string]$Root, [switch]$AsHost, [switch]$NotAdmin)
    Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
    $modules = Join-Path $Root 'modules'
    New-Item -ItemType Directory -Force -Path $modules, (Join-Path $Root 'state'), (Join-Path $Root 'logs') | Out-Null
    $hostReg = 'HKCU:\Software\MOS-test-host'
    Remove-Item -Path $hostReg -Recurse -Force -ErrorAction SilentlyContinue
    $marker = Join-Path $Root '.mos-host'
    if ($AsHost) {
        Set-Content -Path $marker -Value 'test'
        New-Item -Path $hostReg -Force | Out-Null
        New-ItemProperty -Path $hostReg -Name Host -Value 1 -PropertyType DWord -Force | Out-Null
    }
    $isAdmin = if ($NotAdmin) { { $false } } else { { $true } }
    Set-MosConfig @{
        StatePath = Join-Path $Root 'state\state.json'; LogDir = Join-Path $Root 'logs'
        HostMarkerFile = $marker; HostRegKey = $hostReg; ModulesDir = $modules
        KeepListPath = Join-Path $script:TuneDir 'keep-list.psd1'; IsAdmin = $isAdmin; VanguardCheck = $null
    }
    $global:MosFakeStore = @{}
    Register-MosHandler -Type 'Fake' -Fields @('Target') -Handler @{
        Get = { param($t) if ($t.Target -eq 'explode-get') { throw 'get failed' }
            if ($global:MosFakeStore.ContainsKey($t.Target)) { @{ Absent = $false; Value = $global:MosFakeStore[$t.Target] } } else { @{ Absent = $true } } }
        Set = { param($t, $v) if ($t.Target -eq 'explode') { throw 'boom' }
            if ($v.Absent) { $global:MosFakeStore.Remove($t.Target) } else { $global:MosFakeStore[$t.Target] = $v.Value } }
    }
    $modules
}

function Write-MosTestModule {
    param([string]$Dir, [string]$Name, [string]$Body)
    Set-Content -Path (Join-Path $Dir "$Name.psd1") -Value $Body -Encoding UTF8
}

function Clear-MosTestEnv { Remove-Item -Path 'HKCU:\Software\MOS-test-host' -Recurse -Force -ErrorAction SilentlyContinue }
