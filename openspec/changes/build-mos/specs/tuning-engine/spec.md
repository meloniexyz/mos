# Spec Delta

## Purpose

Applies, undoes and audits MOS tweaks in a way that is recorded, reversible and repeatable after Windows updates, and that can never run on the wrong Windows install.

## ADDED Requirements

### Requirement: Runs only on MOS
The tuner SHALL refuse every change-making command unless the host marker created by the MOS bootstrap is present. The read-only check command MAY run anywhere.

#### Scenario: Started on the daily Windows 10
- **WHEN** the user runs apply or undo on a system without the MOS host marker
- **THEN** the tuner exits with an error, changes nothing, and says it only runs on MOS

#### Scenario: Check on another system
- **WHEN** the user runs check on a system without the marker
- **THEN** the tuner reports what it would change and modifies nothing

### Requirement: Requires administrator rights for changes
The tuner SHALL stop before making any change when it is not running elevated.

#### Scenario: Normal user shell
- **WHEN** apply is run without administrator rights
- **THEN** the tuner exits with a message to rerun as administrator and changes nothing

### Requirement: Prior state is recorded before every change
Before changing any setting, the tuner SHALL record that setting's previous value, including "absent", in a persistent state file. A setting already recorded SHALL keep its original value on re-apply.

#### Scenario: First apply
- **WHEN** a tweak changes a registry value that did not exist before
- **THEN** the state file records it as previously absent

#### Scenario: Re-apply after an update
- **WHEN** apply runs again after Windows reset some settings
- **THEN** the reset settings are applied again and the state file still holds the original pre-MOS values

### Requirement: Undo restores recorded state
The tuner SHALL undo a single tweak, a whole module or everything, restoring each setting to its recorded value, and deleting values that were recorded as absent.

#### Scenario: Undo one module
- **WHEN** the user undoes the services module
- **THEN** every service touched by that module returns to its recorded start type and other modules stay applied

### Requirement: Selection by module and tweak
The tuner SHALL let the user apply, undo or check all modules, one module, or one tweak by its identifier.

#### Scenario: Apply one experimental tweak
- **WHEN** the user applies a single experimental tweak by identifier
- **THEN** only that tweak changes and its state is recorded

### Requirement: Read-only drift check
The check command SHALL report, per tweak, whether the system matches the applied MOS value, and SHALL NOT modify anything.

#### Scenario: Windows update reverted a setting
- **WHEN** check runs after an update re-enabled a disabled service
- **THEN** the report lists that tweak as drifted and the system is unchanged

### Requirement: Keep-list is enforced
The tuner SHALL refuse any tweak definition that targets an item on the Vanguard keep-list, even if the definition is present in a module.

#### Scenario: Keep-list item in a module
- **WHEN** a module defines a tweak that disables the firewall engine service
- **THEN** the tuner rejects that tweak, reports the conflict, and applies the remaining tweaks

### Requirement: Dry run
Apply and undo SHALL support a dry run that lists every change they would make without making any.

#### Scenario: Preview
- **WHEN** the user runs apply in dry-run mode
- **THEN** the planned changes are listed and the state file and system are unchanged

### Requirement: Failures are isolated and logged
A failing tweak SHALL NOT stop the remaining tweaks. Every run SHALL write a log listing applied, skipped and failed tweaks with reasons.

#### Scenario: One tweak fails
- **WHEN** one scheduled task cannot be disabled because it does not exist on this build
- **THEN** it is logged as skipped and all other tweaks still run
