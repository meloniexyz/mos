# Design

## Context

See proposal.md for motivation. Facts that shape the approach:

- Target: a desktop PC with a mid-range CPU and an NVIDIA GPU, UEFI firmware with a firmware TPM, where VALORANT is CPU-bound.
- The disk is GPT and may already hold other systems, and possibly more than one EFI system partition. Secure Boot may be off at the start.
- Windows 11 requires TPM 2.0 + Secure Boot for Vanguard. Vanguard's optional on-demand mode additionally needs VBS + HVCI; without them Vanguard runs in its classic always-on mode, which is acceptable on a game-only install.
- Development happens on the daily Windows 10 (PowerShell 5.1). The scripts only do real work on MOS, so most verification happens there.

## Goals / Non-Goals

**Goals:**
- Everything MOS changes is declared as data, recorded before it changes, reversible, and re-checkable after Windows updates.
- Nothing in this repo can modify the daily Windows 10 by accident.
- Built-in tooling only (PowerShell 5.1, bcdedit, powercfg, DISM, Pester 3.4 that ships with Windows), plus PresentMon for measurement.

**Non-Goals:**
- Editing the Windows image (`install.wim`), building a custom ISO file, or integrating drivers offline.
- Automatic partitioning, BIOS changes, or anything on other installed systems.
- A GUI.

## Decisions

### 1. Official media + answer file + first-logon bootstrap, not a modified image
The USB stick is made with Microsoft's Media Creation Tool; `autounattend.xml` and a `MOS\` folder are copied onto its root. Setup reads the answer file automatically.
- *Alternative:* NTLite-style component removal from `install.wim`. Rejected: removed components come back or break on feature updates, removal can't be undone, and it is the riskiest path for Vanguard. The same removals are done post-install by the reversible tuner.

### 2. Answer file contents
- Edition chosen with Microsoft's published generic Windows 11 Pro setup key, so no key or edition prompt appears and activation uses the existing digital license.
- No `DiskConfiguration`/`InstallTo`: the user picks the empty partition. A repo test fails the build if those elements appear.
- OOBE skipped with `HideOnlineAccountScreens`, `HideEULAPage`, `ProtectYourPC=3`, and so on. One local admin account `mos` with an empty password, plus `AutoLogon` (an empty password avoids storing a reusable secret, and Windows blocks network logons for blank-password accounts).
- Computer name `MOS`.
- Time zone and keyboard are placeholders in the repo. `prep-usb.ps1` fills them in from the Windows it runs on, so the public repo holds no personal settings.
- `FirstLogonCommands` runs `bootstrap.ps1` from the USB.

### 3. Bootstrap and host marker
`bootstrap.ps1` scans drive letters for `MOS\mos.usb` (marker file), copies `MOS\` to `C:\MOS`, writes the host marker (`C:\MOS\.mos-host` and `HKLM\SOFTWARE\MOS\Host=1`), fixes the boot menu (see 6), and runs `tune.ps1 apply`.
- If no marker is found, it writes a desktop note with the manual command instead of failing silently.
- If not elevated, it asks once through UAC (see Risks).
- *Alternative:* the `sources\$OEM$` copy mechanism. Rejected: its behavior varies across Setup versions, and a marker scan is easy to test.

### 4. Tuner: declarative tweaks + typed handlers
Each module is a `.psd1` data file listing tweaks: `Id`, `Tier` (standard or experimental), `Type`, target and desired value. The engine has one handler per type — `Registry`, `Service`, `ScheduledTask`, `Appx`, `OptionalFeature`, `PowerSetting`, `Bcd`, `NetAdapterProperty`, `PnpRegistry` (MSI mode), `IniFile` (VALORANT config) and `Script` (custom Get/Set/Test blocks for the few odd cases). Each handler implements `Get` (current value), `Set` and `Test`.
- Apply = for each tweak: Get, record it in state if not already there, Set, Test.
- Undo = restore the recorded value.
- Check = Test only.
- *Alternative:* imperative per-module scripts (the classic debloat-script style). Rejected: undo and drift-check would need hand-written mirrors of every line.

### 5. State file and logging
`C:\MOS\state\state.json` maps tweak id to `{ before, appliedAt }`. The first recorded `before` wins, so a re-apply after an update never overwrites the original value. It is written atomically (temp file + rename), and a timestamped copy is kept before each run. Logs go to `C:\MOS\logs\<date>-<command>.log`.

### 6. Boot menu handling
Windows Setup makes the new install the boot default, and both older entries may be called "Windows 10".
- Before installing, `prep-usb.ps1` runs on the daily Windows 10. It records its own boot entry identifier (`{current}`) into `MOS\boot\main.guid` on the USB.
- The bootstrap then sets that GUID back as `{default}` and renames MOS's own entry to `MOS`.
- "Play VALORANT" (installed on Windows 10 by `install-switch.ps1`) runs `bcdedit /bootsequence <MOS guid>`, found by the description `MOS`, then restarts.
- "Back to Windows" on MOS is a plain restart, because the default is Windows 10 again.
- *Alternative:* renaming the Windows 10 entries to disambiguate. Rejected: the spec allows boot changes only to the MOS entry.

### 7. Keep-list as data, enforced at load time
`keep-list.psd1` lists protected service names (for example `BFE`, `MpsSvc`, `CryptSvc`, `Winmgmt`, `wuauserv`, `TPM`-related services), registry path patterns (CFG/DEP mitigation keys, `CI` policy, crypto) and feature names. Every tweak is validated against it when modules load. A conflicting tweak is rejected and reported, and the rest still run.

### 8. Experimental tier
The experimental tweaks are:
- `FeatureSettingsOverride=3` / `FeatureSettingsOverrideMask=3` (speculative-execution mitigations only)
- HAGS on/off
- A timer-resolution helper started at logon
- An opt-in `defender-quiet` (exclusions for Riot folders + scheduled scans moved, never disabled)

Each one is applied by id only and judged with the bench.

### 9. VBS/HVCI and hypervisor
The standard profile includes `OptionalFeature` tweaks that disable Hyper-V, Virtual Machine Platform, Windows Sandbox and Application Guard. It also sets `hypervisorlaunchtype off` and turns the DeviceGuard VBS/HVCI registry settings off. A separate experimental-tier tweak, `vbs-on`, flips them on, so it can be selected when needed.

### 10. GPU driver
The user installs the NVIDIA driver manually with Custom → Graphics Driver only → Clean install, following INSTALL.md. The gpu module handles MSI mode and removes the NVIDIA App or overlay if present.
- *Alternative:* silent install with component selection. Rejected: it needs the package extracted with third-party tools, and the silent-install switches change between driver releases.

### 11. VALORANT files and Riot Client
`seed-valorant.ps1` (run on MOS) copies VALORANT from the daily Windows 10's `Riot Games\VALORANT` folder, which is visible from MOS under another drive letter. It uses `robocopy` and only reads the source. Then the Riot Client is installed, pointed at the copy and verified, which avoids a ~40 GB download and keeps MOS independent of the daily install. The game module adds the Riot Client to MOS's startup and re-applies the low-graphics INI after the first game launch creates the per-account files (check reports this as drift until then).

### 12. Bench
`bench.ps1` wraps PresentMon's console app. It captures `--process_name VALORANT-Win64-Shipping.exe` for N seconds into `results\<date>-<label>.csv`, computes avg / 1% low / 0.1% low / spread from the frame-time column, and compares labels.
- Noise is estimated from at least two baseline runs. A difference within the larger of the noise band or 2% is reported as "within noise".
- *Alternative:* my per-second counter logger. Rejected: it measurably loaded the CPU during the earlier test.

### 13. Testing
Pester 3.4 tests (they run on the daily Windows 10, read-only) cover:
- The answer-file audit (forbidden elements, edition key, autologon)
- Keep-list validation
- State first-write-wins and undo of "absent" values, using a fake handler
- Module data files parsing
- The host guard refusing to run

Real behavior is checked on MOS with `tune.ps1 check` and `vanguard-check.ps1`.

## Risks / Trade-offs

- **Setup places MOS's boot files on the other EFI partition** (when the disk has more than one) → MOS would be missing from the Windows 10 boot menu. Mitigation: INSTALL.md checks `bcdedit /enum` from Windows 10 after install. The fix is documented: run `bcdboot` for MOS into the ESP the firmware uses.
- **Turning on Secure Boot stops an unsigned OS from booting** (for example an OS on a USB disk) → Mitigation: INSTALL.md says to test-boot it after enabling Secure Boot, and that turning Secure Boot back off restores it. Windows installs are signed and unaffected.
- **Riot starts requiring HVCI on Windows 11** → Mitigation: the `vbs-on` tweak; the vanguard check shows its state.
- **A feature update reverts tweaks or adds new bloat** → Mitigation: run `check` after updates; `apply` is idempotent; Windows Update is set to notify so updates don't run during play.
- **FirstLogonCommands may not run elevated on this build** → Mitigation: the bootstrap detects this and relaunches itself through one UAC prompt. If the prompt is declined, it leaves a desktop note with the manual command. Registering a highest-privilege task needs admin rights too, so it can't serve as the fallback.
- **Empty-password autologon** → Acceptable on a single-user gaming install. The account is blocked from network logon by Windows policy.
- **The 90-day evaluation path is not used** → None.

## Migration Plan

1. On the daily Windows 10, follow INSTALL.md:
   - Shrink C: by about 120 GB.
   - Turn on fTPM + Secure Boot in the BIOS, then test-boot every OS.
   - Make the USB with the Media Creation Tool and run `prep-usb.ps1`.
2. Boot the USB and choose the unallocated space. Setup and the bootstrap finish hands-off.
3. On MOS:
   - Install the NVIDIA driver (custom, driver only).
   - Run `seed-valorant.ps1` and install the Riot Client.
   - Launch VALORANT once, then run `tune.ps1 apply` again.
4. Bench: two baseline runs, then each experimental tweak, keeping the ones that win.
5. On Windows 10, run `install-switch.ps1` for the "Play VALORANT" shortcut.

**Rollback:** `tune.ps1 undo` reverts the tuning. To remove MOS entirely: delete its partition and boot entry from Windows 10 (Disk Management + `bcdedit /delete`) and extend C:. Windows 10 is never modified apart from the shortcut, so nothing there needs reverting.

## Open Questions

- Exact PresentMon 2.x CSV column name for frame time ("MsBetweenPresents" vs "FrameTime"). The bench reads whichever is present.
- Which Windows 11 release the Media Creation Tool serves on install day (25H2 or later). Nothing in the design depends on it.
