# Spec Delta

## ADDED Requirements

### Requirement: Environment snapshot per run
Each capture SHALL save an environment snapshot with its summary:
- RAM configured speed
- display refresh rate
- active power plan
- GPU driver version
- the experimental tweak ids recorded as applied
- whether a restart was pending

#### Scenario: Capture
- **WHEN** a capture finishes
- **THEN** its saved summary includes the snapshot fields

### Requirement: Comparison warns about mismatched environments
When the compared runs' snapshots differ in RAM speed, refresh rate, power plan, GPU driver or pending restart, the comparison SHALL print a warning naming the differences before the results. Differences in experimental tweaks SHALL be listed as information, because they are usually the point of the comparison.

#### Scenario: RAM profile lost between runs
- **WHEN** the reference run had RAM at 3200 MT/s and the other run at 2133 MT/s
- **THEN** compare warns that RAM speed differs and the results are not comparable

#### Scenario: Older runs without a snapshot
- **WHEN** one of the runs has no snapshot
- **THEN** compare notes that the environment can't be checked and still compares the frame metrics
