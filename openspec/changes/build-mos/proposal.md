# Proposal

## Why

On mid-range PCs VALORANT is usually CPU-bound: in busy matches the GPU sits far below full load while the game thread is maxed. Most of the CPU the game competes with comes from everyday apps (browser, chat, music, dev tools) and from background software a daily Windows needs (VPNs, peripheral suites), not from Windows itself. A separate Windows install that exists only to run VALORANT removes that competition entirely, and a measured, reversible tuning pass removes the rest — without breaking Riot Vanguard.

## What Changes

- New: **MOS**, a dedicated Windows 11 Pro boot entry built from Microsoft's official ISO plus files from this repo. No hand-modified Windows image.
- New: hands-off setup (`autounattend.xml`) — local account, no OOBE questions, auto-logon, first-boot bootstrap that copies MOS files and runs the tuner. Disk/partition choice stays manual in Setup.
- New: `tune.ps1` engine with modules (apps, services, tasks, power, gpu, game, network, experimental) supporting `apply`, `undo` and a read-only `check`; every change records the prior value in a state file.
- New: a Vanguard keep-list enforced by the engine, and `vanguard-check.ps1` that verifies CFG/DEP, TPM 2.0, Secure Boot, VBS state and the Vanguard driver.
- New: frame-time benchmarking with PresentMon and a before/after comparison, so experimental tweaks are only kept when they measurably help.
- New: one-click boot switching between the daily Windows 10 and MOS (`bcdedit /bootsequence`).
- New: `INSTALL.md` — shrink C: (~120 GB), BIOS (fTPM + Secure Boot), USB creation, seeding the VALORANT files.
- Out of scope: BIOS overclocking, hardware upgrades, modifying `install.wim`, removing Windows Update or Defender, and the later cleanup of Vanguard/VALORANT from the main Windows.

## Capabilities

### New Capabilities
- `mos-setup`: unattended Windows 11 Pro installation and first-boot bootstrap for the MOS boot entry, including the safety rule that setup never auto-partitions.
- `tuning-engine`: the apply/undo/check runner, recorded prior state, host guard (only runs on MOS), keep-list enforcement and drift reporting.
- `tuning-profile`: the concrete set of tweaks per module, their default tier (standard vs experimental) and what is never touched.
- `vanguard-compat`: checks that MOS still satisfies Riot Vanguard's requirements, and the reversible VBS/HVCI toggle.
- `frametime-bench`: PresentMon capture of a VALORANT session and the comparison/keep-or-undo decision for experimental tweaks.
- `boot-switch`: switching between the daily Windows 10 and MOS with one action from either side.

### Modified Capabilities
<!-- none: new project -->

## Impact

- New repo content: PowerShell 5.1 scripts, `autounattend.xml`, docs. No existing code affected.
- External dependencies the user downloads: Windows 11 Pro ISO/Media Creation Tool (Microsoft), NVIDIA display driver, PresentMon (Intel, MIT).
- Systems touched at install time (by the user, following `INSTALL.md`): C: partition size, BIOS TPM/Secure Boot, the boot menu. Other installed systems and the main Windows are not modified by any script.
- Licensing: MOS activates with the PC's existing Windows Pro digital license.
