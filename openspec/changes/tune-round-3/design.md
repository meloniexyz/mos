# Design

## Context

See proposal.md for motivation. Facts that shape the approach:
- **Power plan:** Windows' High performance plan already defaults to energy-performance preference 0 and boost mode 2 (aggressive), read from `PowerSettings\...\DefaultPowerSchemeValues`. The MOS plan inherits them only when copied from High performance. `powerplan.ps1` falls back to Balanced when High performance is missing.
- **RAM speed:** `Win32_PhysicalMemory` exposes `Speed` (module maximum, often the XMP rate) and `ConfiguredClockSpeed` (current). On some kits `Speed` reports the JEDEC rate. Typical part numbers carry the rated speed (for example `F4-3200C16…`, `CMK16GX4M2B3200C16`, `KF432C16…`).
- **Refresh rate:** WMI monitor modes come from the EDID base block and can under-report high refresh rates. `EnumDisplaySettings` (user32) gives the real current and available modes, but only from an interactive desktop session. `Win32_VideoController.CurrentRefreshRate/MaxRefreshRate` works anywhere.
- **GPU link:** `nvidia-smi` reports PCIe link width current/max. The link generation drops at idle for power saving, so only width is meaningful at rest.
- **New Windows AI service:** `WSAIFabricSvc` exists on newer builds. Users report it keeps running and sometimes ignores a disabled start type. Click to Do and Spotlight have documented policy values.

## Goals / Non-Goals

**Goals:**
- The doctor is pure read: every reading is behind a function that tests can replace with fixed values.
- Snapshot comparison catches the common "different conditions" mistakes without blocking a comparison.

**Non-Goals:**
- Fixing anything from the doctor. It points to the BIOS, Display settings or `tune.ps1`.
- Per-device audio configuration.

## Decisions

### 1. Doctor structure: readers + rules
`doctor.ps1` has two parts:
- **Readers:** one small function per fact. `Get-DocRam`, `Get-DocDisplay`, `Get-DocGpuLink`, `Get-DocPowerPlan`, `Get-DocMsi`, `Get-DocGameMode`, `Get-DocPendingReboot`, `Get-DocFreeSpace`, `Get-DocDriverAge`, `Get-DocBackgroundCpu`.
- **Rules:** `Test-Doc*`, which turn a reading into `{Item, Status, Detail, Hint}`.

`Invoke-MosDoctor -Readings <hashtable>` accepts injected readings, which is how tests drive every rule. `-PassThru` returns objects and prints nothing. It's dot-source friendly, the same pattern as `bench.ps1`.
- *Alternative:* one script that reads and judges inline. Rejected: not testable without the matching hardware state.

### 2. Rated RAM speed
The rated speed is the highest of three values:
- `Speed`
- the first 4-digit number between 1600 and 9600 in the part number
- `ConfiguredClockSpeed`

`WARN` when configured is below rated by more than 50 MT/s. Part-number parsing is a heuristic. When it finds nothing, the rule relies on `Speed` alone. The detail line shows where the rated speed came from.

### 3. Display
Use `EnumDisplaySettings` for the primary display when it returns a mode. Otherwise use `Win32_VideoController` current/max for the adapter driving the primary display. Allow 2 Hz of tolerance, because 239 vs 240 Hz is the same mode.

### 4. Background CPU
`Get-Counter '\Process(*)\% Processor Time'` takes 3 samples over about 5 s. It sums `#n` instances by name and excludes:
- `Idle`, `_Total`, `System`, `Interrupts`
- `dwm`, `csrss`, `audiodg`, `MsMpEng`, `svchost`, `explorer`
- the doctor's own `powershell`

It reports names above 2% of one core. System components are excluded because the user can't close them, and Defender is handled by experiments.

### 5. New tweaks
- **Standard, services module:** `svc-ai-fabric` (Service `WSAIFabricSvc` Disabled; absent counts as satisfied).
- **Standard, apps module:**
  - `policy-no-click-to-do`: `HKCU:\Software\Policies\Microsoft\Windows\WindowsAI\DisableClickToDo = 1`
  - `policy-no-spotlight`: `HKCU:\Software\Policies\Microsoft\Windows\CloudContent\DisableWindowsSpotlightFeatures = 1`
- **Standard, power module:** `power-epp-performance` (PowerSetting `36687f9e-e3a5-4dbf-b1dc-15eb381c6863` = 0) and `power-boost-aggressive` (`be337238-0d82-4146-a960-4f3749d470c7` = 2), both in the MOS plan.
- **Experimental:**
  - `exp-sysmain-off`: Service SysMain Disabled.
  - `exp-memory-compression-off`: Script `memory-compression`.
    - Get: `Get-MMAgent` (admin), reported as unknown without admin.
    - Set: `Disable-MMAgent -MemoryCompression` / `Enable-MMAgent -MemoryCompression`.
    - It takes effect after a restart.
  - `exp-windowed-optimizations`: Script `dx-global-setting`. It edits the `DirectXUserGlobalSettings` string (`key=value;` pairs) under `HKCU:\Software\Microsoft\DirectX\UserGpuPreferences`, setting `SwapEffectUpgradeEnable=1` and keeping all other pairs. Undo restores the exact previous string, or removes the value if it was absent.

The AI Fabric service reportedly can re-enable itself, so `tune.ps1 check` will show it as drift. That's the intended signal to re-apply.

### 6. Bench snapshot
`Save-Summary` adds a `Env` object:
- `RamMts`
- `RefreshHz`
- `PowerPlan` (GUID)
- `GpuDriver`
- `ExperimentalApplied` (ids from `C:\MOS\state\state.json` whose tier is experimental, sorted)
- `PendingRestart`

The values come from the doctor's readers. `bench.ps1` dot-sources `..\doctor.ps1` when present, so one code path reads the facts.

`Compare-Bench` checks each run's `Env` against the reference:
- Differences in RAM, refresh, plan, driver or pending restart: prints `WARNING: environment differs: ...`.
- Different experiment sets: printed as information.
- No `Env`: prints a note.

The frame results are always shown.

### 7. Shortcut and docs
- The bootstrap's "MOS check" shortcut runs `tune.ps1 check` and then `doctor.ps1`.
- INSTALL.md step 2 gets a callout: after any BIOS change, turn the RAM profile back on and run the doctor.
- The game/driver section adds audio advice.

## Risks / Trade-offs

- **Part-number heuristics misread a kit** → The rated speed is the maximum of three sources, and the detail line shows the numbers, so a false WARN is visible and harmless (read-only).
- **`EnumDisplaySettings` fails in non-interactive shells** → Falls back to WMI. The doctor is meant to be run from the desktop shortcut anyway.
- **Memory compression off with low free RAM** → Experimental only, and judged by the bench. The doctor's free-space and background checks give context.
- **`WSAIFabricSvc` re-enables itself** → Shown as drift by `check`, so it's re-applied.

## Migration Plan

1. Archive `build-mos`, then `tune-round-2`, then this change.
2. On MOS, `tune.ps1 apply` adds the new standard tweaks.
3. The doctor is available immediately from the shortcut or `C:\MOS\doctor.ps1`.

**Rollback:** `tune.ps1 undo -Id <id>`. The doctor and snapshot are read-only and can simply be ignored.
