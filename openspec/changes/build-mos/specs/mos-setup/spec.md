# Spec Delta

## Purpose

Installs MOS — a Windows 11 Pro boot entry used only for VALORANT — from Microsoft's official media with no setup questions, and bootstraps it on first logon, without ever risking the other operating systems on the machine.

## ADDED Requirements

### Requirement: Setup never partitions automatically
The unattended answer file SHALL NOT contain any disk wipe, partition creation or automatic install-target selection. The user MUST choose the target partition in Windows Setup.

#### Scenario: Setup reaches disk selection
- **WHEN** Windows Setup runs from the MOS USB stick
- **THEN** Setup stops at the "Where do you want to install Windows?" screen and waits for the user's choice

#### Scenario: Answer file audit
- **WHEN** the answer file is checked by the repo's validation
- **THEN** validation fails if it contains `DiskConfiguration`, `WillWipeDisk`, `InstallTo` or `InstallToAvailablePartition`

### Requirement: Windows 11 Pro edition without prompts
Setup SHALL install the Windows 11 Pro edition from the official image without asking for a product key or edition, so that it activates with the PC's existing digital license.

#### Scenario: Edition and activation
- **WHEN** installation completes and the PC is online
- **THEN** the installed edition is Windows 11 Pro and it activates with the existing digital license, with no key typed by the user

### Requirement: Out-of-box experience is skipped
Setup SHALL create one local administrator account and skip Microsoft-account sign-in, privacy, region and keyboard questions.

#### Scenario: First boot
- **WHEN** the installed system boots for the first time
- **THEN** no OOBE screen asks for input and the local account is created

### Requirement: Regional settings come from the main Windows
The answer file in the repository SHALL contain no time zone or keyboard layout. The USB preparation step SHALL fill them in from the Windows it runs on.

#### Scenario: Preparing the stick
- **WHEN** the USB preparation runs on the main Windows
- **THEN** the answer file on the stick has that Windows' time zone and keyboard layouts, and the repository copy still holds only placeholders

### Requirement: Automatic logon
MOS SHALL log on to its local account automatically at every boot.

#### Scenario: Reboot into MOS
- **WHEN** MOS boots
- **THEN** the desktop appears without a password prompt

### Requirement: First-logon bootstrap
On the first logon, MOS SHALL copy the MOS files from the install USB (found by a marker file, on any drive letter) to a fixed folder on the MOS system drive, mark the host as MOS, and run the standard tuning profile once.

#### Scenario: USB still plugged in
- **WHEN** the first logon runs and the USB stick with the marker file is present
- **THEN** the MOS files exist in the fixed folder, the host marker exists, and the standard profile has been applied with its state recorded

#### Scenario: USB removed too early
- **WHEN** the first logon runs and no drive contains the marker file
- **THEN** nothing is tuned and a message on the desktop explains how to run the bootstrap manually

### Requirement: Other installs are untouched
No MOS setup or bootstrap step SHALL modify any partition, file or boot setting belonging to the main Windows or any other installed system, other than adding and naming the MOS boot entry.

#### Scenario: After installing MOS
- **WHEN** the user boots the daily Windows 10 after MOS was installed
- **THEN** it starts as before, with its files and its default boot entry unchanged
