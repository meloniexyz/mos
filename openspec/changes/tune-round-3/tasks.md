# Tasks

## 1. Doctor

- [x] 1.1 Write `usb/MOS/doctor.ps1` readers (RAM, display, GPU link, power plan, MSI, Game Mode, pending restart, free space, driver age, background CPU) and rules, with `Invoke-MosDoctor -Readings` injection and `-PassThru`. Verify with Pester tests that drive every rule with injected readings, covering PASS and WARN for RAM (2133 vs 3200, rated from the part number), refresh (60 vs 240, and 239 vs 240 PASS), link width 8/16, plan, MSI, Game Mode, pending restart, free space, driver age and background load.
- [x] 1.2 Run the doctor for real, read-only, on the main Windows, both printed and with `-PassThru`. Verify that it completes without errors, prints every item, and changes nothing (no files under C:\MOS, registry untouched).

## 2. New tweaks

- [x] 2.1 Add the standard tweaks `svc-ai-fabric`, `policy-no-click-to-do`, `policy-no-spotlight`, `power-epp-performance` and `power-boost-aggressive`. Verify that all modules load with zero rejected tweaks, and a read-only `check` reports them.
- [x] 2.2 Write the `memory-compression` and `dx-global-setting` script tweaks, and add `exp-sysmain-off`, `exp-memory-compression-off` and `exp-windowed-optimizations`. Verify with Pester tests:
  - the DirectX string merge keeps other pairs and undo restores the exact string or removes it (using a sandbox key)
  - default apply selects none of the three, and each is selectable by id
  - memory compression reports unknown without admin

## 3. Bench snapshot

- [x] 3.1 Add the `Env` snapshot to `Save-Summary` (via the doctor's readers) and environment warnings to `Compare-Bench`. Verify with Pester tests:
  - the snapshot fields are saved
  - a RAM speed difference prints the not-comparable warning
  - differing experiment sets are listed as information
  - runs without a snapshot get the note and frame metrics are still compared

## 4. Shortcut and docs

- [x] 4.1 Make the bootstrap's "MOS check" shortcut run `tune.ps1 check` then `doctor.ps1`. Update `docs/INSTALL.md`:
  - BIOS callout: re-enable XMP/DOCP after defaults, run the doctor
  - doctor usage in step 5 and day-to-day
  - audio advice
  - new experiments in the test order

  Regenerate `docs/TWEAKS.md`. Verify with the bootstrap tests, the parameter/command check of INSTALL.md, and the full Pester suite.

## 5. On MOS (after `build-mos` and `tune-round-2` on-hardware tasks)

- [ ] 5.1 Run the doctor on MOS after install and after the BIOS changes. Verify that every item is PASS (or INFO for driver age), and fix any WARN it reports.
- [ ] 5.2 Bench `exp-sysmain-off`, `exp-memory-compression-off` and `exp-windowed-optimizations` with snapshots. Verify that the compare reports show no environment warnings and their results are recorded in TWEAKS.md.

## Workflow follow-up

- Archive order: `build-mos`, then `tune-round-2`, then this change.
