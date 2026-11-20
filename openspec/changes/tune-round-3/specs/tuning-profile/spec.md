# Spec Delta

## ADDED Requirements

### Requirement: AI and suggestion background work off
The standard profile SHALL disable the Windows AI Fabric service, turn off Click to Do, and turn off Windows Spotlight content. A system without the service SHALL count as already satisfied.

#### Scenario: Build without the AI service
- **WHEN** the standard profile is applied on a build that has no AI Fabric service
- **THEN** that tweak reports as already at the MOS value and nothing fails

### Requirement: Performance-first CPU hints in the MOS plan
The MOS power plan SHALL set the processor energy-performance preference to 0 (performance) and the boost mode to aggressive, whatever plan it was copied from.

#### Scenario: Plan copied from Balanced
- **WHEN** the MOS plan had to be created from Balanced
- **THEN** after apply its energy-performance preference is 0 and boost mode is aggressive

### Requirement: Memory and presentation experiments
The experimental tier SHALL add, each selectable on its own and reversible:
- SysMain (Superfetch) off
- memory compression off
- optimizations for windowed games on

#### Scenario: Memory compression experiment
- **WHEN** the memory compression tweak is applied and later undone
- **THEN** compression is off after apply (effective after restart), and back to its recorded state after undo

#### Scenario: Windowed-games setting keeps other DirectX preferences
- **WHEN** the user's DirectX global preferences already hold other entries and the windowed-games tweak is applied
- **THEN** only the windowed-games entry is added or changed, and undo restores the exact previous string
