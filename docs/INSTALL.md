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

Other BIOS settings (RAM profile, fan curves) are not affected.

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
5. **Launch VALORANT once** so it creates its settings files. In Video > Graphics Quality, set:
   - **Multithreaded Rendering: On**
   - **NVIDIA Reflex: On + Boost**
   - **Vignette, Improve Clarity, Experimental Sharpening, Bloom, Distortion, Cast Shadows: Off**

   Then close the game.
6. **Apply again** to set the low-graphics profile and Riot Client autostart. In an admin terminal:

   ```powershell
   C:\MOS\tune\tune.ps1 apply
   ```

7. **Check Vanguard compatibility.** Every line should say PASS:

   ```powershell
   C:\MOS\vanguard-check.ps1
   ```

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

## 9. Experimental tweaks (one at a time)

For each group (`exp-spectre-*`, `exp-hags-off`, `exp-timer-*`, `exp-defender-quiet`):

1. `C:\MOS\tune\tune.ps1 apply -Id exp-spectre-*`
2. **Restart.**
3. `bench.ps1 capture -Label spectre-off`, then `bench.ps1 compare -Label baseline, spectre-off`.
4. If there's no `gain` on avg or 1% low: `tune.ps1 undo -Id exp-spectre-*` and restart.
5. Write the result into the "Bench result" column of `docs/TWEAKS.md` (in this repo) and run `tools\gen-tweaks-doc.ps1`.

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
