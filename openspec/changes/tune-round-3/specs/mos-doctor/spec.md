# Spec Delta

## Purpose

Reports, without changing anything, the conditions that silently cost VALORANT performance on an otherwise tuned install: a lost RAM profile, a display below its refresh rate, a narrowed GPU link, a pending restart, or stray background load.

## ADDED Requirements

### Requirement: Read-only report
The doctor SHALL change nothing on the system. It SHALL run with or without administrator rights. Items it cannot read without them SHALL be reported as UNKNOWN with a hint, not as failures.

#### Scenario: Normal user shell
- **WHEN** the doctor runs without administrator rights
- **THEN** it prints a report, every item is PASS, WARN, INFO or UNKNOWN, and no setting, file or service has changed

### Requirement: RAM at rated speed
The doctor SHALL compare each memory module's configured speed with its rated speed, taken from the module's reported maximum speed or a speed in its part number. It SHALL WARN when the configured speed is lower, with a hint to turn the XMP/DOCP/EXPO profile back on in the BIOS.

#### Scenario: Profile lost after a BIOS reset
- **WHEN** modules rated 3200 MT/s run at 2133 MT/s
- **THEN** the RAM item is WARN and names both speeds and the BIOS fix

#### Scenario: Profile on
- **WHEN** the configured speed equals the rated speed
- **THEN** the RAM item is PASS

### Requirement: Display at maximum refresh rate
The doctor SHALL WARN when the primary display's current refresh rate is more than 2 Hz below the highest rate available at its current resolution.

#### Scenario: Monitor left at 60 Hz
- **WHEN** the display runs at 60 Hz and 240 Hz is available
- **THEN** the refresh item is WARN with a hint to pick the highest rate in Display settings

### Requirement: GPU link width
The doctor SHALL WARN when an NVIDIA GPU's current PCIe link width is lower than its maximum. It SHALL report INFO when the width can't be read.

#### Scenario: GPU in a narrowed slot
- **WHEN** the GPU reports link width 8 with a maximum of 16
- **THEN** the GPU link item is WARN with a hint about the slot or riser

### Requirement: Tuning state items
The doctor SHALL report, with WARN on mismatch:
- the active power plan is the MOS plan
- GPU interrupts are message-signaled
- Game Mode is on
- no restart is pending
- the system drive has at least 30 GB free

It SHALL report the GPU driver age as INFO, or as WARN when older than 180 days.

#### Scenario: Restart pending after tuning
- **WHEN** Windows reports a pending restart
- **THEN** the pending-restart item is WARN, saying some tweaks are not active until the restart

### Requirement: Background CPU load
The doctor SHALL sample processor use per process for about 5 seconds. It SHALL list non-system processes above 2% of one core as WARN, so stray programs can be closed before playing.

#### Scenario: A browser left open
- **WHEN** a browser is using 30% of a core during the sample
- **THEN** the background item is WARN and names it with its load

### Requirement: Machine-readable result
The doctor SHALL return its results as objects when asked, so other MOS tools can embed them.

#### Scenario: Used by the bench
- **WHEN** another script calls the doctor for objects
- **THEN** it receives one object per item with item, status, detail and hint, and nothing is printed
