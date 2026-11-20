# MOS

MOS is a separate Windows 11 Pro install used only to play VALORANT on this PC. It is built from Microsoft's official installer plus the files in this repo, then tuned by a reversible script.

Start with [docs/INSTALL.md](docs/INSTALL.md). Every tweak is listed in [docs/TWEAKS.md](docs/TWEAKS.md).

## Layout

| Path | What it is | Runs on |
|------|------------|---------|
| `usb/autounattend.xml` | Hands-off Windows Setup answers (never partitions) | Windows Setup |
| `usb/MOS/` | Everything copied to the USB stick, then to `C:\MOS` on MOS | MOS |
| `usb/MOS/bootstrap.ps1` | First-logon setup: copy files, fix boot menu, tune | MOS |
| `usb/MOS/tune/` | `tune.ps1 apply / undo / check`, its modules and handlers | MOS (check runs anywhere) |
| `usb/MOS/vanguard-check.ps1` | Read-only Riot Vanguard compatibility report | anywhere |
| `usb/MOS/bench/bench.ps1` | PresentMon frame-time capture, summary and comparison | MOS |
| `usb/MOS/seed-valorant.ps1` | Copies the existing VALORANT files to MOS | MOS |
| `windows10/prep-usb.ps1` | Copies MOS files onto the setup USB and records the boot entry | daily Windows 10 |
| `windows10/install-switch.ps1` | Adds the "Play VALORANT" one-click reboot | daily Windows 10 |
| `tests/` | Pester 3.4 tests (`Invoke-Pester tests`) | anywhere, read-only |

## Safety rules built into the scripts

- `tune.ps1 apply/undo` refuse to run anywhere except MOS, and need admin rights.
- The answer file never wipes or picks a disk. You choose the partition in Setup.
- A keep-list blocks any tweak that touches what Riot Vanguard needs: CFG/DEP, crypto, WMI, code integrity, firewall engine, TPM, Windows Update, Defender.
- Every tweak saves the previous value first, so it can be undone.
