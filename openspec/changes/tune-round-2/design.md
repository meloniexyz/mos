# Design

## Context

See proposal.md for motivation. This change builds on the `build-mos` tuner:
- Tweaks are declared in `usb/MOS/tune/modules/*.psd1` and run through typed handlers.
- The keep-list (`keep-list.psd1`) is checked when modules load: `RegistryKeyPatterns` with wildcards, plus `RegistryValueNames` protected anywhere.
- The code-integrity key `HKLM:\SYSTEM\CurrentControlSet\Control\CI*` is protected as a whole, which is why Smart App Control can't be turned off today.
- The `Bcd` handler already supports `Remove = $true`.
- `PnpRegistry` writes one value per matched device. Its Set passes values through `New-ItemProperty` without type conversion, so binary values aren't supported yet.
- `bench.ps1 capture` runs PresentMon and summarizes frame times. No other sampling happens during a capture.

## Goals / Non-Goals

**Goals:**
- Every new tweak is a declarative entry using an existing handler where possible, recorded and undoable like the rest.
- Keep-list exceptions can open exactly one value and never a pattern.
- System counters cost less than the run-to-run noise. When they're off, nothing extra runs.

**Non-Goals:**
- Choosing interrupt targets automatically per CPU topology. One fixed, documented target is enough for an experiment.
- Scripted NVIDIA driver profile changes, which would need a third-party tool. These stay as documented manual steps.
- Changing the bench's frame metrics or their definitions.

## Decisions

### 1. Keep-list exceptions as exact (Key, Name) pairs
`keep-list.psd1` gains `RegistryExceptions = @( @{ Key = '<exact key>'; Name = '<exact value>' } )`.

In `Test-MosKeepList`, the order is:
1. Protected value names are rejected first, so an exception can never re-open an exploit-mitigation value.
2. For a key-pattern hit, the tweak is allowed only if `(Target, Name)` equals an exception, compared case-insensitively.

`Import-MosTweaks` validates exceptions before loading any module. Any `*`, `?` or `[` in an exception, or a missing Key or Name, fails the whole load.
- *Alternative:* per-tweak "force" flags in modules. Rejected: the protection would then depend on every module author, instead of living in one reviewed file.

### 2. Smart App Control off: `CI\Policy\VerifiedAndReputablePolicyState = 0`
This is a Registry tweak in the services module, standard tier. It's the only exception added to the keep-list.
- It takes effect after a reboot.
- On builds before the 2026 servicing update that made SAC toggleable, Windows treats "off" as permanent. Undo still writes the recorded value back, but Windows may not re-enable SAC. TWEAKS.md says so.
- The Vanguard check's test-signing, CFG and DEP items show code integrity itself is unaffected.

### 3. Forced platform clock: `Bcd` tweak `useplatformclock` with `Remove = $true`
This uses the existing handler, in the power module, standard tier. "Already absent" reports as unchanged.
- *Not added:* `disabledynamictick` and `useplatformtick`. Reports conflict, some show worse latency or odd mouse feel, and they're hard to reason about.

### 4. Display and scheduling experiments
- **MPO off:** Registry `HKLM:\SOFTWARE\Microsoft\Windows\Dwm\OverlayTestMode = 5` (DWord). Reboot needed. Undo removes the value.
- **Priority separation:** Registry `HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation = 0x26` (short, variable quanta, highest foreground boost). One fixed value, so the bench compares exactly two states.
- **Fullscreen optimizations off:** a new `Script` tweak `fso-valorant`.
  - It finds the VALORANT executable: the Riot product install path if available, else `<SystemDrive>\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe`.
  - It sets the AppCompat `Layers` value for that path, adding the `DISABLEDXMAXIMIZEDWINDOWEDMODE` token and keeping any other tokens already there.
  - If the executable is missing, it returns `Skip`.
  - A plain Registry tweak can't express the path, because the value name depends on where the game is installed.

### 5. GPU interrupt affinity via `PnpRegistry`
There are two experimental tweaks, selected together with `exp-gpu-irq-*`. Both target `Device Parameters\Interrupt Management\Affinity Policy` on `PCI\VEN_10DE*` display devices:
- `DevicePolicy = 4` (DWord: IrqPolicySpecifiedProcessors)
- `AssignmentSetOverride` (Binary, 8 bytes): bit 2, meaning logical processor 2, the first thread of the second physical core on SMT CPUs

The `PnpRegistry` Set converts the value to `[byte[]]` when `ValueType` is `Binary`. That's the only handler change.

Fixed CPU 2 rather than "last CPU": it works on any CPU with 4 or more threads, and it keeps the module purely declarative. MSI mode (already standard) stays on, since affinity policy applies to MSI interrupts too.

### 6. Bench counters as a separate low-rate sampler
`bench.ps1 capture -WithCounters` starts a child PowerShell process (`Start-Job`). It samples every 5 s:
- `\Processor(_Total)\% Interrupt Time`
- `\Processor(_Total)\% DPC Time`
- `\Processor(*)\% Processor Time` (the busiest instance, excluding `_Total`)

It writes `<run>.counters.csv` and stops when PresentMon returns. The summary gains `IntPctMed/P90`, `DpcPctMed/P90` and `BusiestCoreMed/P90` only when that file exists.

Compare adds interrupt % and DPC % rows when both runs have them, and for these a lower value counts as a gain.
- *Why not the earlier per-second logger:* it started `nvidia-smi` and read every core's counter once per second, which measurably loaded the CPU. Every 5 s with counters only is cheap, and it's off by default, so reference runs stay clean.

### 7. Docs
INSTALL.md gains a "Game and driver settings" section:
- VALORANT's per-account settings sync through the Riot account (configure once, MOS inherits them). The graphics-quality file is per PC and set by the tuner.
- Raw Input Buffer: off at 1000 Hz polling, try it on for 2–8 kHz mice.
- NVIDIA shader cache: 10 GB or unlimited.
- Frame cap test with Reflex: uncapped vs. a cap slightly above typical fps, compared on 1% lows.

The experimental test order starts with `exp-defender-quiet`, since Defender was the largest Windows background consumer measured at idle.

### 8. Explicitly not done
These are recorded so they aren't re-proposed:
- **ETW autologger disabling:** no measured benefit, and disabling Defender or EventLog autologgers is a known evasion technique that security tools flag.
- **VALORANT/Riot process affinity or priority** (IFEO, Process Lasso style): reported to stop Vanguard. IFEO stays keep-listed and a profile audit test asserts it.
- **Offline image editing:** it would speed up the first boot, but adds no in-match fps over post-install tuning.

## Risks / Trade-offs

- **SAC can't be re-enabled on older builds** → It's documented in TWEAKS.md. MOS installs a current 25H2+ build, where SAC is toggleable.
- **The MPO key is ignored on some Windows builds**, or hurts windowed flip mode → Experimental only. VALORANT in exclusive fullscreen is mostly unaffected; judge by the bench.
- **IRQ affinity makes latency worse**, if CPU 2 is busy with the game thread → The counters show interrupt/DPC load, and undo is one command.
- **Priority separation is likely placebo** → It's kept only on a bench "gain" outside noise.
- **The sampler itself adds load** → Every 5 s, off by default; compare only runs with the same counter setting.

## Migration Plan

1. Archive `build-mos` first, so its capabilities exist as main specs.
2. Implement, then run the tests and regenerate TWEAKS.md.
3. On MOS, `tune.ps1 apply` picks up the two new standard tweaks; restart for SAC.
4. Experiments go through the INSTALL.md bench procedure.

**Rollback:** `tune.ps1 undo -Id <id>` per tweak. Reverting the code change itself only affects future runs, because state already recorded still undoes correctly (it stores each tweak's definition).
