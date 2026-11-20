# Spec Delta

## Purpose

Makes moving between the daily Windows 10 and MOS a single action, so playing on a separate install costs one reboot instead of a trip through the boot menu.

## ADDED Requirements

### Requirement: Play from the daily Windows
The daily Windows 10 SHALL get a "Play VALORANT" shortcut that reboots once into MOS, leaving the default boot entry unchanged.

#### Scenario: One-time switch
- **WHEN** the user runs the shortcut on the daily Windows 10 and confirms the elevation prompt
- **THEN** the PC restarts into MOS, and the following normal reboot starts the daily Windows 10 again

### Requirement: Back from MOS
MOS SHALL have a "Back to Windows" shortcut that reboots once into the daily Windows 10.

#### Scenario: Return
- **WHEN** the user runs the shortcut on MOS
- **THEN** the PC restarts into the daily Windows 10

### Requirement: Boot entries found by name
The switch SHALL locate the target boot entry by its description and SHALL stop with a clear message, without rebooting, if the entry is missing or the name matches more than one entry.

#### Scenario: Ambiguous entry
- **WHEN** two boot entries share the description used by the switch
- **THEN** the switch lists them, does not reboot, and explains how to rename one

### Requirement: Default boot entry preserved
Installing MOS and using the switch SHALL leave the daily Windows 10 as the boot menu default.

#### Scenario: Cold boot
- **WHEN** the PC is powered on normally
- **THEN** the daily Windows 10 starts by default after the menu timeout

### Requirement: Riot Client starts on MOS logon
MOS SHALL start the Riot Client automatically after auto-logon.

#### Scenario: Switch to MOS
- **WHEN** MOS finishes booting
- **THEN** the Riot Client opens without user action
