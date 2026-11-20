# Spec Delta

## Purpose

Keeps MOS compatible with Riot Vanguard after tuning by checking the security features Vanguard depends on, and lets VBS/HVCI be switched on again if Riot starts requiring it.

## ADDED Requirements

### Requirement: Compatibility report
A read-only check SHALL report pass or fail for: Windows 11 version, Secure Boot on, TPM 2.0 present and ready, system-wide CFG on, DEP on, test-signing off, kernel debugging off, VBS/HVCI state, and the Vanguard driver installed and running.

#### Scenario: Healthy MOS
- **WHEN** the check runs on a tuned MOS with Vanguard installed
- **THEN** every item reports pass, and VBS/HVCI is reported as off by design

#### Scenario: Secure Boot turned off
- **WHEN** the check runs after Secure Boot was disabled in the BIOS
- **THEN** the Secure Boot item fails with a hint to re-enable it in the BIOS

### Requirement: Check runs after every apply
The tuner SHALL run the compatibility check at the end of every apply and show any failures.

#### Scenario: A tweak breaks a requirement
- **WHEN** an apply leaves DEP disabled
- **THEN** the run ends with a visible failure naming DEP

### Requirement: VBS/HVCI toggle
MOS SHALL keep VBS and HVCI off by default, and SHALL provide one reversible tweak that turns them on, for use if Vanguard starts requiring them or the user wants Vanguard's on-demand mode.

#### Scenario: Riot requires HVCI
- **WHEN** the user applies the VBS/HVCI tweak and reboots
- **THEN** VBS and HVCI report as running, and undoing the tweak turns them off again after a reboot

### Requirement: Hypervisor features off
MOS SHALL keep Hyper-V, Virtual Machine Platform, Windows Sandbox and Application Guard disabled.

#### Scenario: After setup
- **WHEN** the compatibility check runs
- **THEN** it reports these features as disabled
