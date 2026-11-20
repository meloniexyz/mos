# Proposal

## Why

Round 3 looked beyond Windows bloat at what silently costs fps on a working install. These things don't show up as "a tweak missing". They show up as a slower PC with no visible cause:
- **A BIOS change resets the RAM profile (XMP/DOCP) to default speed.** MOS's install guide tells the user to change BIOS settings, and loading defaults there turns the profile off. This costs roughly 10–15% on CPU-bound games.
- **The monitor runs below its maximum refresh rate.**
- **The GPU is on a narrower PCIe link than it supports.**
- **A restart is still pending**, so tweaks aren't active yet.
- **A stray program is using the CPU** in the background.

Benchmarks also can't tell when two runs were taken under different conditions. A run after a BIOS reset would look like a tweak "loss".

Newer Windows 11 builds also add an AI service (`WSAIFabricSvc`) that users report keeping the CPU, NPU and RAM busy. The MOS power plan only gets its performance-first CPU hints from the High performance plan it copies, and loses them when it falls back to Balanced.

## What Changes

- **New `doctor.ps1`:** a read-only health report that runs anywhere. It checks:
  - RAM running at its rated speed (XMP/DOCP on)
  - display at its maximum refresh rate
  - GPU PCIe link width
  - MOS power plan active
  - GPU MSI mode active
  - Game Mode on
  - no pending restart
  - free space on the system drive
  - GPU driver age
  - background programs using CPU right now

  Each item is PASS / WARN / INFO with a fix hint.
- **New standard tweaks:**
  - AI Fabric service off
  - Click to Do off
  - Windows Spotlight content off
  - CPU energy-performance preference set to performance (0) in the MOS plan
  - aggressive boost mode set in the MOS plan
- **New experimental tweaks:**
  - SysMain (Superfetch) off
  - memory compression off
  - optimizations for windowed games on (only matters if VALORANT runs windowed or borderless)
- **Bench:**
  - Each capture saves an environment snapshot with the summary: RAM speed, refresh rate, power plan, GPU driver, the experimental tweaks applied, and pending restart.
  - Compare warns when the runs' environments differ, so mismatched runs aren't read as tweak results.
- **Desktop and docs:**
  - The "MOS check" shortcut also runs the doctor.
  - INSTALL.md tells the user to re-check XMP/DOCP after BIOS changes and run the doctor.
  - Audio advice: enhancements and spatial sound off unless the headset needs virtual surround.
- **Not added:** a power-preference tweak as a separate experiment (already covered above), and audio registry changes (per-device and headset-dependent, so documented only).

## Capabilities

### New Capabilities
- `mos-doctor`: read-only health report of the conditions that silently cost performance, with fix hints.

### Modified Capabilities
These are introduced by the unarchived `build-mos` change. Archive `build-mos` (then `tune-round-2`) before this change.
- `tuning-profile`: the new standard and experimental tweaks above.
- `frametime-bench`: environment snapshot per run and mismatch warnings in compare.

## Impact

- **New:** `usb/MOS/doctor.ps1`.
- **Changed:**
  - `usb/MOS/tune/modules/*.psd1` (new tweaks)
  - new script tweaks for memory compression and the windowed-games setting
  - `usb/MOS/bench/bench.ps1` (snapshot + mismatch warning)
  - `usb/MOS/bootstrap.ps1` (shortcut runs the doctor)
  - `docs/INSTALL.md`, `docs/TWEAKS.md`
- **Tests:** new Pester cases for the doctor's checks (with injected readings), the new tweaks, and snapshot comparison.
- **No change** to setup, the boot switch or the keep-list. Nothing runs on the main Windows except the read-only doctor, if the user chooses to run it there.
