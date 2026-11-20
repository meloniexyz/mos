# Tasks

## 1. Keep-list exceptions

- [x] 1.1 Add `RegistryExceptions` support to `Test-MosKeepList` and validate exceptions in `Import-MosTweaks`: exact key + value only, protected value names always win, wildcard or incomplete exceptions fail the load. Verify with Pester tests covering the four scenarios in `specs/tuning-engine/spec.md` (allowed value, neighbouring value rejected, wildcard exception refused, value-name list still wins).
- [x] 1.2 Add the single exception `HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy` / `VerifiedAndReputablePolicyState` to `keep-list.psd1`. Verify that the existing keep-list tests still pass and that a tweak on any other `CI\Policy` value is still rejected.

## 2. New standard tweaks

- [x] 2.1 Add `sac-off` (Registry, services module) and `boot-no-platform-clock` (Bcd `useplatformclock`, `Remove = $true`, power module). Verify that all modules load with zero rejected tweaks, and that `tune.ps1 check` on the main Windows reports both read-only (Bcd as unknown without admin).

## 3. New experimental tweaks

- [x] 3.1 Add `exp-mpo-off` (Dwm `OverlayTestMode = 5`) and `exp-priority-separation` (`Win32PrioritySeparation = 0x26`) to the experimental module. Verify with a Pester test that default apply selects neither and that each is selected by its id.
- [x] 3.2 Write the `fso-valorant` script tweak (find the executable, merge the `DISABLEDXMAXIMIZEDWINDOWEDMODE` token into the AppCompat Layers value, skip if the game is missing) and add `exp-fso-off`. Verify with Pester tests: token merge keeps existing tokens, undo restores the exact previous string, and a missing executable gives `skipped`.
- [x] 3.3 Add Binary support to the `PnpRegistry` handler (cast to `[byte[]]`) and the `exp-gpu-irq-policy` / `exp-gpu-irq-mask` tweaks (DevicePolicy 4, AssignmentSetOverride bit 2). Verify with a Pester test of the byte conversion and equality on round-trip. Also verify a read-only `check -Id exp-gpu-irq-*` on the main Windows finds the GPU without changing anything.
- [x] 3.4 Add a profile-audit Pester test: no tweak sets affinity or priority on VALORANT/Riot processes, and an IFEO-targeting tweak is still rejected. Verify that it passes.

## 4. Bench counters

- [x] 4.1 Add `-WithCounters` to `bench.ps1 capture`: a background sampler every 5 s writing `<run>.counters.csv`, stopped when PresentMon exits. Verify with a Pester test that runs the sampler function for ~12 s against a temp file and gets 2–3 rows, and that without the switch no sampler is started.
- [x] 4.2 Extend the summary and compare: median/p90 interrupt %, DPC % and busiest core when counter data exists; in compare, lower is better for these. Verify with Pester tests on synthetic counter CSVs (fields present only with counters; a drop in DPC % reported as gain).

## 5. Docs

- [x] 5.1 Update `docs/INSTALL.md`: a "Game and driver settings" section (settings that sync through the Riot account vs. the per-PC graphics file, Raw Input Buffer by polling rate, NVIDIA shader cache, frame-cap test with Reflex), the new experiments in step 9 with `exp-defender-quiet` first, and `-WithCounters` usage. Verify that every command and parameter named exists (same check as `build-mos` 9.2).
- [x] 5.2 Note the SAC re-enable caveat in the tweak's Why text, regenerate `docs/TWEAKS.md`, and run the full Pester suite. Verify that all tests pass and that TWEAKS.md lists every new id.

## 6. On MOS (after `build-mos` group 10)

- [ ] 6.1 Apply the standard profile on MOS and restart. Verify that Windows Security shows Smart App Control off and `vanguard-check.ps1` still passes every item.
- [ ] 6.2 Bench the experiments one group at a time with `-WithCounters`, starting with `exp-defender-quiet`. Verify that each has a compare report in `results\` and its kept/undone result in TWEAKS.md.

## Workflow follow-up

- Archive `build-mos` before archiving this change (this change adds requirements to capabilities `build-mos` introduces).
- Archive this change after 6.2.
