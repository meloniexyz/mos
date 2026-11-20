# Spec Delta

## Purpose

Measures VALORANT's real frame times on MOS with negligible overhead, so tuning decisions are based on numbers from this PC instead of tweak lists.

## ADDED Requirements

### Requirement: Capture a VALORANT session
The bench SHALL record per-frame timing of the VALORANT process for a chosen duration, labelled with a run name, using a low-overhead capture that does not poll the CPU or GPU every second.

#### Scenario: Labelled capture
- **WHEN** the user starts a 120-second capture named "baseline" while VALORANT is running
- **THEN** a capture file for "baseline" is saved with one row per frame

#### Scenario: Game not running
- **WHEN** a capture starts and VALORANT is not running
- **THEN** the bench waits for the game process and starts recording when it appears, or exits with a message after a timeout

### Requirement: Summary metrics
For every capture, the bench SHALL report average fps, 1% low fps, 0.1% low fps, and the frame-time spread.

#### Scenario: Summary
- **WHEN** a capture finishes
- **THEN** the summary with these metrics is printed and saved next to the capture

### Requirement: Before/after comparison
The bench SHALL compare two or more labelled captures and show the difference per metric, flagging differences smaller than the run-to-run noise measured between repeated baseline runs.

#### Scenario: Experimental tweak comparison
- **WHEN** the user compares "baseline" with "spectre-off"
- **THEN** the change in average and 1% low fps is shown, marked as a real gain or as within noise

### Requirement: Results stay with the repo
Captures and summaries SHALL be stored in a results folder inside the MOS files, named by date and label.

#### Scenario: Later review
- **WHEN** the user opens the results folder after several sessions
- **THEN** every past capture and summary is there with its date and label
