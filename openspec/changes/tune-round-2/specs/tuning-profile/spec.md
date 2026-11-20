# Spec Delta

## ADDED Requirements

### Requirement: Smart App Control off
The standard profile SHALL turn Smart App Control off, so that it never starts blocking unsigned MOS scripts or checking every program launch. Driver signature enforcement and the other code-integrity protections SHALL stay as Windows set them.

#### Scenario: After the standard profile
- **WHEN** the standard profile has been applied and the PC restarted
- **THEN** Windows Security reports Smart App Control as off, and the Vanguard compatibility check still passes its test-signing, CFG and DEP items

### Requirement: Forced platform clock stays unset
The standard profile SHALL ensure the boot entry has no forced platform clock setting. It SHALL only remove that setting, never add it.

#### Scenario: Something had forced the platform clock
- **WHEN** the MOS boot entry has a platform clock override and the standard profile is applied
- **THEN** the override is removed, and undo puts the recorded value back

#### Scenario: Normal system
- **WHEN** the boot entry has no platform clock override
- **THEN** the tweak reports it as already at the MOS value and changes nothing

### Requirement: Display and scheduling experiments
The experimental tier SHALL add, each selectable on its own and reversible:
- multiplane overlay off
- fullscreen optimizations off for the VALORANT executable
- a foreground-boost scheduler priority separation value

#### Scenario: Fullscreen optimizations before the game is installed
- **WHEN** the fullscreen-optimizations tweak is applied and the VALORANT executable does not exist yet
- **THEN** the tweak is skipped with a message to apply it again after installing the game

#### Scenario: Reverting an experiment
- **WHEN** the user undoes the multiplane overlay tweak
- **THEN** the overlay setting returns to its recorded state (removed if it was absent)

### Requirement: GPU interrupt affinity experiment
The experimental tier SHALL include a tweak that routes the NVIDIA GPU's interrupts to one logical processor other than CPU 0. It SHALL use Windows' per-device interrupt affinity policy and leave every other device untouched.

#### Scenario: Applying the affinity experiment
- **WHEN** the GPU interrupt affinity tweak is applied and the PC restarted
- **THEN** the GPU's interrupt policy names a single processor other than CPU 0, and undo restores the previous policy

#### Scenario: No NVIDIA GPU present
- **WHEN** no present display device matches the NVIDIA vendor id
- **THEN** the tweak is skipped with a message

### Requirement: Never touch game process scheduling
No tweak SHALL set CPU affinity or priority on the VALORANT or Riot processes, by any mechanism, because doing so is known to interfere with Riot Vanguard.

#### Scenario: Profile audit
- **WHEN** every module is loaded
- **THEN** no tweak targets VALORANT or Riot process priority or affinity, and the keep-list still rejects Image File Execution Options entries
