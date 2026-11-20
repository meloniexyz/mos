# Tasks

## 1. Scaffolding

- [x] 1.1 Create the repo layout (`usb/autounattend.xml`, `usb/MOS/` with `mos.usb` marker; everything that goes onto the stick lives under `usb/MOS/`: `tune/`, `tune/modules/`, `tune/handlers/`, `bench/`; Windows 10-side scripts in `windows10/`; `tests/`, `docs/`) plus `README.md`, and `git init`. Verify that `git status` shows the tree and `Invoke-Pester tests` runs (with zero tests).

## 2. Tuning engine core

- [x] 2.1 Implement the host guard (`.mos-host` file + `HKLM\SOFTWARE\MOS\Host`) and the admin check. Verify with a Pester test that apply/undo refuse to run without the marker and that check is allowed.
- [x] 2.2 Implement module loading from `.psd1` files with schema validation (Id, Tier, Type, target, value). Verify with a Pester test that a malformed tweak is reported and the valid ones load.
- [x] 2.3 Implement the keep-list (`keep-list.psd1`) and enforce it at load time. Verify with a Pester test that tweaks targeting `BFE`, `MpsSvc`, `CryptSvc`, `Winmgmt`, `wuauserv` or the CFG/DEP mitigation keys are rejected while other tweaks still load.
- [x] 2.4 Implement the state store: first-write-wins `before` values, a recorded "absent" sentinel, atomic write, and a pre-run backup copy. Verify with Pester tests for re-apply keeping the original value and for corrupted-file recovery from the backup.
- [x] 2.5 Implement the apply/undo/check runner with selection by all/module/tweak id, the experimental-tier opt-in, dry run, per-tweak error isolation and logging to `logs\<date>-<command>.log`. Verify with Pester tests using a fake in-memory handler: default apply skips experimental tweaks, dry run changes nothing, one failing tweak doesn't stop the others, and undo restores "absent" by deleting the value.

## 3. Handlers

- [x] 3.1 Implement the `Registry`, `Service`, `ScheduledTask` and `PowerSetting` handlers (Get/Set/Test). Verify by running `tune.ps1 check` on the daily Windows 10, which is read-only and should report current values without errors, plus Pester tests of Registry handler Get/Test against a temporary `HKCU:\Software\MOS-test` key.
- [x] 3.2 Implement the `Appx`, `OptionalFeature`, `Bcd`, `NetAdapterProperty`, `PnpRegistry` (MSI mode), `IniFile` and `Script` handlers. Verify by running `check` read-only on the daily Windows 10, then a Pester test of the `IniFile` handler on a copied VALORANT settings file in a temp folder.

## 4. Tuning profile modules

- [x] 4.1 Write the `apps` and `services` modules, which keep WebView2, VC++ runtimes and Store infrastructure. Verify that the modules load with zero keep-list conflicts and that `apply -DryRun` lists the expected items.
- [x] 4.2 Write the `tasks`, `power` (MOS plan: min 100%, core parking off, no sleep or throttle states, idle states untouched) and `network` (EEE/green Ethernet off, no TCP globals) modules. Verify that they load cleanly and the dry-run output matches the spec items.
- [x] 4.3 Write the `gpu` (MSI mode, NVIDIA App/overlay removal) and `game` (Game DVR/background capture off, Game Mode on, low-graphics INI with backup, Riot Client startup entry) modules. Verify that they load cleanly and the INI tweak's dry run shows every settings file it would change.
- [x] 4.4 Write the `experimental` module: speculative-execution override (mask 3 only), HAGS, the timer-resolution helper, `defender-quiet` and `vbs-on`. Also add the standard-tier hypervisor-off tweaks (Hyper-V, VM Platform, Sandbox, App Guard, `hypervisorlaunchtype off`, VBS/HVCI registry off). Verify with a Pester test that default apply selects none of the experimental ids and that none of them touch CFG/DEP.
- [x] 4.5 Document every tweak (id, tier, what/why, how to undo) in `docs/TWEAKS.md`, generated from the module data. Verify that the generator output lists every tweak id found in the modules.

## 5. Vanguard compatibility

- [x] 5.1 Implement `vanguard-check.ps1`, a read-only report of Windows 11 version, Secure Boot, TPM 2.0 ready, CFG/DEP, test-signing and kernel debug off, VBS/HVCI state, hypervisor features off, and the `vgk` driver/`vgc` service. Verify by running it on the daily Windows 10, where it should report real values with Windows 10 and Secure Boot as expected fails.
- [x] 5.2 Call the vanguard check at the end of every `apply` and surface failures. Verify with a Pester test that a simulated DEP failure is shown in the run summary.

## 6. Unattended setup and bootstrap

- [x] 6.1 Write `autounattend.xml`: the generic Windows 11 Pro setup key, OOBE skipped, local `mos` account with blank password, AutoLogon, computer name `MOS`, and FirstLogonCommands calling the bootstrap. There must be no disk configuration. Verify with a Pester answer-file audit test (forbidden elements absent, key/account/autologon present, valid XML).
- [x] 6.2 Write `prep-usb.ps1` (run on Windows 10). It finds the USB by the `mos.usb` marker, copies `usb\` content to the stick root and records `{current}` into `MOS\boot\main.guid`. Verify with a dry run against a temp folder standing in for the stick, which should produce the expected tree and GUID file.
- [x] 6.3 Write `bootstrap.ps1`: find the USB by marker, copy to `C:\MOS`, write the host markers, restore `{default}` from `main.guid`, rename the current entry to `MOS`, run `tune.ps1 apply`, and fall back to one UAC relaunch, then a desktop note. Verify with a Pester test of the drive-scan and fallback logic using fake drive roots.

## 7. Boot switch

- [x] 7.1 Write `install-switch.ps1` (Windows 10 side), which creates the "Play VALORANT" shortcut running an elevated `bcdedit /bootsequence <MOS>` + restart, finding MOS by description and refusing on 0 or more than 1 match. Write the MOS-side "Back to Windows" restart shortcut. Verify with a Pester test of the entry-matching logic on captured `bcdedit /enum` output samples (one match, none, two).

## 8. Bench

- [x] 8.1 Write `bench.ps1 capture`, which wraps PresentMon CLI (process name, duration, label) and waits for the VALORANT process or times out. Verify with a Pester test of argument building and the timeout path. A real capture is checked in 10.4.
- [x] 8.2 Write `bench.ps1 summary/compare`, which computes avg, 1% low, 0.1% low and spread from either frame-time column name, estimates noise from repeated baselines, and flags "within noise". Verify with Pester tests on synthetic CSVs with known answers.

## 9. VALORANT seeding and install guide

- [x] 9.1 Write `seed-valorant.ps1`, which locates `Riot Games\VALORANT` on the other Windows drive letters and copies it with robocopy to the MOS drive, reading only from the source. Verify with a dry run (`robocopy /L`) on the daily Windows 10 against a temp target.
- [x] 9.2 Write `docs/INSTALL.md` covering: shrinking C: by ~120 GB, BIOS fTPM + Secure Boot (and test-booting every other installed OS afterwards), Media Creation Tool USB + `prep-usb.ps1`, choosing the unallocated space, checking the boot menu and the two-EFI-partition fix, NVIDIA custom driver-only install, seeding VALORANT + Riot Client, first launch + re-apply, bench procedure, rollback and full removal. Verify by walking through each command for syntax against the scripts' actual parameters.

## 10. On-hardware integration (needs the user to install MOS)

- [ ] 10.1 Install MOS following INSTALL.md. Verify that no setup prompts appear except disk selection, auto-logon works, `C:\MOS` and the host marker exist, and Windows 10 is still the boot default.
- [ ] 10.2 Run `tune.ps1 check` and `vanguard-check.ps1` on MOS. Verify that the check shows no drift and every Vanguard item passes (VBS off by design).
- [ ] 10.3 Install the driver, seed VALORANT, install the Riot Client, launch once and re-apply. Verify that VALORANT starts without VAN errors and its INI shows the low profile.
- [ ] 10.4 Run two baseline bench captures in deathmatch, then each experimental tweak. Verify that the comparison report exists in `results\`, with the kept/undone decision for each tweak recorded in `docs/TWEAKS.md`.
- [ ] 10.5 Install the boot switch on Windows 10 and test both directions. Verify that one click goes to MOS, and a restart from MOS returns to Windows 10.

## Workflow follow-up

- After MOS is proven, plan a separate change for removing Vanguard and VALORANT from the main Windows.
- Archive this change after the on-hardware checks pass.
