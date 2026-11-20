. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

Describe 'TWEAKS.md generator (4.5)' {
    It 'lists every tweak id from the modules and keeps bench notes' {
        $out = Join-Path $TestDrive 'TWEAKS.md'
        & (Join-Path $script:RepoRoot 'tools\gen-tweaks-doc.ps1') -OutFile $out 6>$null
        Import-Module (Join-Path $script:TuneDir 'MosTune.psm1') -Force
        Set-MosConfig @{ ModulesDir = (Join-Path $script:TuneDir 'modules'); KeepListPath = (Join-Path $script:TuneDir 'keep-list.psd1') }
        $ids = (Import-MosTweaks).Tweaks | ForEach-Object { $_.Id }
        $text = Get-Content $out -Raw
        foreach ($id in $ids) { $text | Should Match ([regex]::Escape("| ``$id`` |")) }

        # a bench note written by hand survives regeneration
        $edited = $text -replace '(\| `exp-hags-off` \|.*\|) not tested yet \|', '$1 kept: +4% 1% lows |'
        Set-Content -Path $out -Value $edited -Encoding UTF8
        & (Join-Path $script:RepoRoot 'tools\gen-tweaks-doc.ps1') -OutFile $out 6>$null
        (Get-Content $out -Raw) | Should Match 'exp-hags-off.*kept: \+4% 1% lows'
    }
}
