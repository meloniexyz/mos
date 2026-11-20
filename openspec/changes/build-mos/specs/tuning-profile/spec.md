# Spec Delta

## Purpose

Defines which Windows changes MOS makes to give VALORANT's CPU-bound game thread the least competition, which are experimental, and which are never made.

## ADDED Requirements

### Requirement: Standard and experimental tiers
Every tweak SHALL belong to the standard tier or the experimental tier. Apply without a selection SHALL apply only standard tweaks. Experimental tweaks SHALL be applied only when selected individually.

#### Scenario: Default apply
- **WHEN** the user runs apply with no selection
- **THEN** all standard tweaks are applied and no experimental tweak is

### Requirement: Bundled apps removed
The apps module SHALL remove the preinstalled consumer apps and AI features (for example Store games, Xbox apps, Teams, Copilot, Recall, Widgets, OneDrive, the Edge browser) while keeping the WebView2 runtime, Microsoft Store infrastructure needed by system components, and the VC++ runtimes.

#### Scenario: After apps module
- **WHEN** the apps module has been applied
- **THEN** the listed consumer apps are gone and the WebView2 runtime is still installed

### Requirement: Background services reduced
The services module SHALL set only services with no role in running VALORANT (such as search indexing, print spooler, telemetry, Xbox, phone link, maps, fax) to manual or disabled, and SHALL leave core OS, networking, audio, crypto, firewall-engine and update services at their defaults.

#### Scenario: Audio and networking after services module
- **WHEN** the services module has been applied
- **THEN** sound plays, the network connects, and Windows Update can still be run manually

### Requirement: Background tasks reduced
The tasks module SHALL disable scheduled tasks that wake the CPU for telemetry, compatibility appraisal, customer-experience reporting and app maintenance.

#### Scenario: Idle CPU after tasks module
- **WHEN** MOS sits idle at the desktop after the tasks module
- **THEN** none of the disabled tasks run

### Requirement: Power plan for sustained boost
The power module SHALL activate a MOS power plan based on a minimal-change approach: processor minimum state 100%, core parking off, no display or disk sleep, and no throttle states. It SHALL NOT disable CPU idle states on SMT processors.

#### Scenario: Active plan
- **WHEN** the power module has been applied
- **THEN** the MOS plan is active, and CPU idle states are still enabled

### Requirement: GPU interrupt and driver setup
The gpu module SHALL enable MSI interrupt mode on the NVIDIA GPU and SHALL support installing only the NVIDIA display driver from a user-provided installer, without the NVIDIA App.

#### Scenario: After gpu module
- **WHEN** the gpu module has been applied and the PC rebooted
- **THEN** the GPU uses message-signaled interrupts and no NVIDIA App or overlay process is running

### Requirement: Game settings
The game module SHALL disable Game DVR and background capture, keep Game Mode on, and set VALORANT's settings file to the competitive low-graphics profile with a backup of the previous file.

#### Scenario: Game settings applied
- **WHEN** the game module has been applied
- **THEN** background recording is off and VALORANT's graphics groups are at their lowest values, with the previous file backed up

### Requirement: Network adapter latency settings
The network module SHALL turn off energy-efficient Ethernet and green/power-saving features on the wired adapter where the driver exposes them, and SHALL NOT change TCP stack globals.

#### Scenario: Wired adapter
- **WHEN** the network module has been applied
- **THEN** the adapter's power-saving properties are off and the connection still works

### Requirement: Experimental tweaks are measured
The experimental tier SHALL include at least the speculative-execution mitigation override, the hardware-accelerated GPU scheduling setting and a global timer resolution request. Each SHALL be kept only if a frame-time comparison shows an improvement.

#### Scenario: Experimental tweak shows no gain
- **WHEN** a frame-time comparison shows no improvement for an experimental tweak
- **THEN** the documented procedure is to undo that tweak

### Requirement: Never-touch list
No tweak SHALL disable CFG, DEP or other exploit protections, remove or disable crypto, certificate, WMI or code-integrity components, the firewall engine, TPM services, Windows Update components or Defender components. Defender MAY only be switched off through its supported settings as an opt-in tweak.

#### Scenario: Full apply
- **WHEN** every standard and experimental tweak has been applied
- **THEN** CFG and DEP are still enabled system-wide and Windows Update can still check for updates
