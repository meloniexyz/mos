# Installing MOS

MOS is a second Windows (Windows 11 Pro) on the same disk as your main Windows, used only for VALORANT. Your main Windows (C:) and any other installed systems stay as they are, and your main Windows stays the boot default.

Total time: about 1–1.5 hours, most of it waiting for downloads and installs.

> **Never delete, format or merge partitions in Windows Setup.** You only pick the empty space you create in step 1.

---

## 0. What you need

- A USB stick of 8 GB or more. **Everything on it is erased**, so don't use a disk that holds anything you need.
- About 120 GB of free space on C:.
- Optional, for benchmarking: **PresentMon** (Intel, free). From github.com/GameTechDev/PresentMon/releases, download the console app (`PresentMon-<version>-x64.exe`) and put it in `usb\MOS\bench\tools\` in this repo before step 3.

## 1. Make room: shrink C:

1. Right-click Start > **Disk Management**.
2. Right-click **C:** > **Shrink Volume**.
3. In "Enter the amount of space to shrink in MB", type `122880` (120 GB) > **Shrink**.
4. You now have **120 GB Unallocated** right after C:. Leave it unallocated; Setup will use it.

## 2. BIOS: TPM and Secure Boot

Windows 11 and Riot Vanguard need both. To see where you stand, run `usb\MOS\vanguard-check.ps1` from this repo in an admin terminal: it reports the TPM and Secure Boot state.

Menu names differ by board maker. The usual places (ASUS shown; MSI, Gigabyte and ASRock are similar):

1. Restart and enter the BIOS (usually **Del** or **F2**). On ASUS, press **F7** for Advanced Mode.
2. **TPM:** turn on the firmware TPM.
   - AMD: **AMD fTPM** / "Firmware TPM".
   - Intel: **PTT** / "Platform Trust Technology".
3. **CSM (Compatibility Support Module): Disabled.**
4. **Secure Boot:** turn it on, with OS Type **Windows UEFI mode**. If it shows *Setup Mode* or no keys: **Key Management > Install default Secure Boot keys**.
5. Save and restart.
6. **Test-boot every OS you have** (other Windows installs, Linux, OS-on-USB disks).
   - Windows installs are signed and boot normally.
   - An unsigned OS won't boot with Secure Boot on. Turning Secure Boot off again brings it back, but MOS then fails the Vanguard check, so decide which matters more.

7. **Check the RAM profile is still on.** "Load optimized defaults" (and some board updates) turn XMP / DOCP / EXPO off, which silently costs a lot of fps in CPU-bound games. In the BIOS, set the memory profile again (ASUS: Ai Tweaker > Ai Overclock Tuner > D.O.C.P / XMP).
   - Then, from Windows, run the doctor from this repo:

     ```powershell
     powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\MOS\usb\MOS\doctor.ps1"
     ```
   - "RAM speed" must say PASS.

## 3. Make the USB stick

1. On microsoft.com/software-download/windows11, download the **Media Creation Tool** and run it.
2. Choose **English (United States)**, **Windows 11**, then **USB flash drive**, and pick your stick.
3. When it's done, open **Terminal (Admin)** and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\MOS\windows10\prep-usb.ps1"
   ```

   It finds the stick by itself (or add `-Target E:\`). It then:
   - copies `autounattend.xml` and the `MOS` folder onto the stick
   - records your Windows 10 boot entry, so MOS keeps it as the default

## 4. Install MOS

1. Restart and press **F8** for the boot menu. Choose **UEFI: <your USB stick>**.
2. Setup runs without questions until **"Where do you want to install Windows?"**
3. Select the **120 GB Unallocated Space** on Drive 0 and click **Next**. Delete nothing.
4. Windows installs and restarts a few times.
   - The boot menu may already show Windows 10 as default; if it boots Windows 10, press **F8** and pick the SSD's Windows Boot Manager, then choose **MOS / Windows 11**.
   - Leave the USB stick plugged in until the desktop appears.
5. On the first desktop, a PowerShell window runs the **bootstrap**, which:
   - copies the files to `C:\MOS`
   - sets the Windows 10 boot default back, and names this entry **MOS**
   - makes auto-logon permanent
   - applies the standard tuning profile

   The bootstrap is done when **"MOS next steps.txt"** appears on the desktop. If it shows "MOS setup NOT finished.txt", follow that note.

**If the boot menu has no "MOS" entry** when you're back in Windows 10 (run `bcdedit /enum` in an admin terminal): Setup wrote MOS's boot files to the other EFI partition on this disk. Boot MOS once via **F8**, then run in an admin terminal on MOS:

```powershell
mountvol S: /S
```
```powershell
bcdboot C:\Windows /s S: /f UEFI
```
```powershell
bcdedit /default (Get-Content C:\MOS\boot\main.guid)
```

Then rename the new entry: `bcdedit /set {current} description "MOS"`.

## 5. First steps on MOS

1. **Restart once.** Hyper-V/VBS removal and GPU interrupt mode only take effect after a reboot.
2. **NVIDIA driver:** download the latest GeForce driver for your card from nvidia.com. Run it and choose:
   - **NVIDIA Graphics Driver** only (not the NVIDIA App)
   - **Custom > Graphics Driver** only
   - **Perform a clean installation**
3. **Copy VALORANT from your main Windows** instead of downloading it again (tens of GB). In an admin terminal:

   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\MOS\seed-valorant.ps1
   ```

   It finds `Riot Games\VALORANT` on your other drives (the newest copy) and copies it to `C:\Riot Games\VALORANT`. It only reads from the source.
4. **Riot Client:** download it from playvalorant.com and install it to `C:\Riot Games`.
   - In the client, choose **Install VALORANT** and set the location to `C:\Riot Games`.
   - It finds the copied files and only verifies them.
   - Vanguard installs too. **Restart** when asked.
5. **Launch VALORANT once** so it creates its settings files.
   - Most in-game settings sync through your Riot account, so whatever you set on another PC appears here too. See "Game and driver settings" below.
   - Check Video > Graphics Quality once (see "Game and driver settings"), then close the game.
6. **Apply again**: this sets the per-PC graphics quality file, Riot Client autostart, and the fullscreen-optimizations experiment if you use it. In an admin terminal:

   ```powershell
   C:\MOS\tune\tune.ps1 apply
   ```

7. **Check Vanguard compatibility.** Every line should say PASS:

   ```powershell
   C:\MOS\vanguard-check.ps1
   ```
8. **Restart once more.** Smart App Control's off switch (`sac-off`) takes effect after a reboot.
9. **Run the doctor**, using the **MOS check** desktop shortcut (it runs the tuning check, then the doctor).
   - Every item should be PASS, or INFO for driver age. Fix any WARN using its hint.
   - It catches what silently costs fps: RAM profile off, monitor below its max refresh rate, GPU link narrowed, wrong power plan, MSI mode lost after a driver reinstall, restart pending, programs left running.

### Game and driver settings

These live outside Windows, so the tuner doesn't set them.

**Where VALORANT keeps its settings:**
- **Synced through your Riot account** (`RiotUserSettings.ini`): Reflex, bloom, distortion, cast shadows, vignette, sharpening, texture/detail/material quality, frame cap, blood/corpses and more. Set them once on any PC and MOS gets them at login.
- **Per PC** (`GameUserSettings.ini`): the graphics quality groups. MOS's `valorant-low-graphics` tweak sets these to lowest.

**Recommended in-game values for a CPU-bound PC:**

| Setting | Value | Why |
|---|---|---|
| Multithreaded Rendering | On | spreads render work off the main thread |
| NVIDIA Reflex | On + Boost | lowest latency, keeps GPU clocks up |
| Material / Texture / Detail / UI quality | Low | |
| Vignette, Improve Clarity, Sharpening, Bloom, Distortion, Cast Shadows | Off | |
| Show Blood, Show Corpses | Off | fewer objects to draw in fights |
| Anisotropic filtering | 1x | |
| Raw Input Buffer (Settings > General > Mouse) | Off with a 1000 Hz mouse; try On with 2000–8000 Hz | it only helps high-polling mice and can cost fps otherwise |

**NVIDIA Control Panel > Manage 3D settings:**
- **Shader Cache Size:** 10 GB or Unlimited (fewer re-compiles after driver or game updates).
- **Power management mode:** Prefer maximum performance.
- **Texture filtering quality:** High performance.
- **Low Latency Mode:** leave it; Reflex in the game takes over.

**Audio (Windows sound settings, per output device):**
- Turn off **Audio enhancements** and **Spatial sound**, unless your headset needs virtual surround (then keep the one it needs).
- Use **24-bit, 48000 Hz**. Higher sample rates only add audio-engine CPU work.

**Frame cap test:** with Reflex On + Boost, compare **no cap** against **a cap slightly above your usual deathmatch fps**. Use the bench (step 8) and keep whichever gives better 1% lows. A steady cap often feels smoother than a higher, swinging average.

## 6. One-click switch from Windows 10

On the daily Windows 10, in an admin terminal:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\MOS\windows10\install-switch.ps1"
```

- **Play VALORANT** (Windows 10 desktop): asks for admin, then restarts into MOS once. The Riot Client opens by itself.
- **Back to Windows** (MOS desktop): restarts into Windows 10, which is the default.

## 7. Day to day

| Situation | Command (admin terminal on MOS) |
|---|---|
| After a Windows update | `C:\MOS\tune\tune.ps1 check`, then `apply` if anything drifted |
| fps feels lower than usual, or after any BIOS / driver change | **MOS check** shortcut, or `C:\MOS\doctor.ps1`: fix any WARN |
| Undo one tweak / module / everything | `tune.ps1 undo -Id <id>` / `undo -Module <name>` / `undo` |
| Preview without changing | `tune.ps1 apply -DryRun` |
| Windows Update | Settings > Windows Update > Check for updates. MOS never downloads updates on its own (they would start during a match). |

Logs are in `C:\MOS\logs`; the recorded "before" values are in `C:\MOS\state\state.json`. All tweaks are listed in [TWEAKS.md](TWEAKS.md).

## 8. Benchmark (needs PresentMon in `C:\MOS\bench\tools`)

Use the same thing every run: a full deathmatch, recording for 120 s once the match is busy.

- Run it in an admin terminal, then start a deathmatch.
- It waits for the game, then records:

  ```powershell
  C:\MOS\bench\bench.ps1 capture -Label baseline -Seconds 120
  ```
- **Do two baseline runs.** Their difference is the noise; anything smaller isn't a real change.
- Compare runs, reference first:

  ```powershell
  C:\MOS\bench\bench.ps1 compare -Label baseline, spectre-off
  ```

The metrics:
- **1% low** is the fps of the average of the slowest 1% of frames; **0.1% low** is the same for the slowest 0.1%. They show stutter, which the average hides.
- The comparison marks each difference as `gain`, `loss` or `within noise`.

**System counters (optional):** add `-WithCounters` to also record interrupt %, DPC % and the busiest core every 5 seconds. `compare` then shows those too, where lower is better.
- Use it for the interrupt experiment (`exp-gpu-irq-*`).
- Only compare runs that were recorded the same way: all with counters or all without.

## 9. Experimental tweaks (one at a time)

Test the groups in this order. The first ones are the most likely to matter:

| Order | Group | What it changes |
|---|---|---|
| 1 | `exp-defender-quiet` | Defender skips the Riot folders and scans only when idle (Defender was the largest Windows background load measured at idle) |
| 2 | `exp-spectre-*` | Spectre/Meltdown kernel mitigations off |
| 3 | `exp-hags-off` | GPU scheduling back to the driver |
| 4 | `exp-mpo-off` | multiplane overlay off |
| 5 | `exp-gpu-irq-*` | GPU interrupts on CPU 2 instead of CPU 0 (bench with `-WithCounters`) |
| 6 | `exp-timer-*` | 0.5 ms timer resolution |
| 7 | `exp-priority-separation` | stronger foreground scheduling boost |
| 8 | `exp-fso-off` | fullscreen optimizations off for VALORANT |
| 9 | `exp-sysmain-off` | SysMain (Superfetch) off |
| 10 | `exp-memory-compression-off` | memory compression off (needs plenty of free RAM) |
| 11 | `exp-windowed-optimizations` | flip-model presentation for windowed/borderless; only if you play windowed |

Each benchmark run also saves a snapshot of the conditions: RAM speed, refresh rate, power plan, driver, applied experiments and pending restart. If two runs differ in any of those, `compare` warns that the results are **not comparable**. A RAM profile lost after a BIOS change would otherwise look like a tweak "loss".

For each group:

1. `C:\MOS\tune\tune.ps1 apply -Id exp-spectre-*`
2. **Restart.**
3. `bench.ps1 capture -Label spectre-off`, then `bench.ps1 compare -Label baseline, spectre-off`.
4. If there's no `gain` on avg or 1% low: `tune.ps1 undo -Id exp-spectre-*` and restart.
5. Write the result into the "Bench result" column of `docs/TWEAKS.md` (in this repo) and run `tools\gen-tweaks-doc.ps1`.

Keep the winners applied when you test the next group, so they add up. Re-take a baseline after keeping one.

**Never** set priority or CPU affinity on VALORANT or the Riot Client (Task Manager, Process Lasso, registry tricks). It's reported to stop Vanguard, and MOS blocks it on purpose.

`exp-vbs-on-*` is not a performance experiment. Only apply it if Riot starts requiring memory integrity, or if you want Vanguard's on-demand mode.

## 10. Rollback and removal

- **Undo all tuning:** `C:\MOS\tune\tune.ps1 undo`, then restart.
- **Remove MOS completely** (from Windows 10, admin):
  1. Run `bcdedit /enum` and find the entry described **MOS**.
  2. Delete it with `bcdedit /delete {<its id>}`.
  3. In Disk Management, delete the MOS partition (~120 GB; check the size, and that it isn't C: or any other system's partition).
  4. Right-click C: > **Extend Volume**.
  5. Delete the "Play VALORANT" shortcut and `C:\ProgramData\MOS-switch`.
- Windows 10 itself was never changed by any of this, apart from the shortcut.
