# Spec Delta

## ADDED Requirements

### Requirement: Optional system counters during capture
A capture SHALL optionally record system counters at a low rate (at most one sample every 5 seconds) alongside the frame times: total interrupt time %, total DPC time %, and the busiest logical processor's load. Counters SHALL be off by default.

#### Scenario: Capture with counters
- **WHEN** the user captures a session with system counters turned on
- **THEN** the run's summary also holds median and 90th-percentile interrupt %, DPC % and busiest-core load

#### Scenario: Capture without counters
- **WHEN** the user captures without turning counters on
- **THEN** no counter sampling runs during the capture and the summary has no counter fields

### Requirement: Counters shown in comparisons
When the compared runs have counter data, the comparison SHALL show the difference in interrupt % and DPC % next to the frame metrics. Runs without counter data SHALL be compared on frame metrics only.

#### Scenario: Interrupt affinity experiment
- **WHEN** the user compares a baseline with counters against an interrupt-affinity run with counters
- **THEN** the comparison lists the change in interrupt % and DPC % as well as fps and 1% lows
