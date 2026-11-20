# Proposal

## Why

A research pass after `build-mos` reached two conclusions. MOS already covers the changes with the largest measured effect: a separate OS, VBS/HVCI off, and Windows 11 25H2+. A small set of gaps remains:

- Smart App Control starts in evaluation mode on new installs. If it switches to On, it would block MOS's own unsigned scripts.
- Nothing guarantees the forced-HPET boot setting stays unset.
- A few tweaks with mixed evidence (MPO, fullscreen optimizations, scheduler priority separation, GPU interrupt placement) can only be judged by measuring, and the bench can't yet see interrupt/DPC load.
- On an idle Windows install, Defender is the largest Windows background consumer, while all services together are minor. Defender exclusions are therefore the first experiment worth benching.

## What Changes

- **Standard tweak: Smart App Control off.**
  - Needs a narrow keep-list exception: one named value under the protected code-integrity key.
  - The rest of that key stays protected.
- **Standard tweak: forced platform clock unset.** It removes `useplatformclock` from the boot entry if anything set it; it never adds it.
- **Keep-list: exact-value exceptions.**
  - The keep-list can allow one specific registry value inside a protected key.
  - Exceptions are listed explicitly, so a pattern can never widen them.
- **Experimental tweaks:**
  - MPO off (DWM overlay test mode).
  - Fullscreen optimizations off for the VALORANT executable.
  - Scheduler foreground priority separation.
  - GPU interrupt affinity moved off CPU 0.
- **Bench: optional low-rate system counters** (interrupt %, DPC %, per-core load) during a capture, saved with the summary and shown in compare. Off by default, so the reference runs stay clean.
- **Docs:**
  - INSTALL.md adds the in-game and driver settings that are not Windows tweaks: Raw Input Buffer by mouse polling rate, NVIDIA shader cache size, frame cap testing with Reflex.
  - It explains that VALORANT's per-account settings sync through the Riot account, while the graphics quality file is per PC.
  - TWEAKS.md is regenerated.
- **Explicitly not added**, with reasons recorded in design.md:
  - dynamic tick and platform tick boot options
  - ETW autologger disabling
  - process affinity/priority for VALORANT, which is known to interfere with Vanguard
  - offline image editing

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
The capabilities below are introduced by the unarchived `build-mos` change, so this change adds requirements to them. Archive `build-mos` before this change.
- `tuning-engine`: keep-list gains exact-value exceptions.
- `tuning-profile`: new standard tweaks (Smart App Control off, forced platform clock unset) and new experimental tweaks (MPO, fullscreen optimizations, priority separation, GPU interrupt affinity).
- `frametime-bench`: optional system counters during capture.

## Impact

- **Code:**
  - `usb/MOS/tune/MosTune.psm1` (keep-list exception check)
  - `usb/MOS/tune/keep-list.psd1`
  - `usb/MOS/tune/modules/*.psd1` (new tweaks)
  - possibly one new handler for per-device interrupt affinity
  - `usb/MOS/bench/bench.ps1`
- **Tests:** new Pester cases for the exception rule, the new tweaks loading cleanly, and the bench counter summary.
- **Docs:** `docs/INSTALL.md` and `docs/TWEAKS.md` (regenerated).
- **No change** to setup, bootstrap, the boot switch or the Vanguard check. Nothing runs on the main Windows.
