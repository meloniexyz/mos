# Active power plan. MOS value: the "MOS" plan (fixed GUID), created as a copy of High performance
# (or Balanced if High performance is not available). Undo re-activates the previously active plan.
$highPerf = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'

function Get-ActivePlan {
    $out = powercfg /getactivescheme
    if ("$out" -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { return $Matches[1].ToLower() }
    throw "Can't read the active power plan: $out"
}
function Test-PlanExists([string]$Guid) { "$(powercfg /list)" -match [regex]::Escape($Guid) }

@{
    Get     = { param($t) @{ Absent = $false; Value = (Get-ActivePlan) } }
    Desired = { param($t, $cur) @{ Absent = $false; Value = (Get-MosPlanGuid) } }
    Set     = {
        param($t, $v)
        $target = [string]$v.Value
        if ($target -eq (Get-MosPlanGuid) -and -not (Test-PlanExists $target)) {
            $base = if (Test-PlanExists $highPerf) { $highPerf } else { $balanced }
            powercfg /duplicatescheme $base $target | Out-Null
            if ($LASTEXITCODE) { throw "powercfg /duplicatescheme failed ($LASTEXITCODE)" }
            powercfg /changename $target 'MOS' 'MOS: VALORANT only (managed by tune.ps1)' | Out-Null
        }
        powercfg /setactive $target | Out-Null
        if ($LASTEXITCODE) { throw "powercfg /setactive $target failed ($LASTEXITCODE)" }
    }
}
