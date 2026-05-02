# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachoproject.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-05-03

### Added

- **Hermes service preset** — One-click configuration for Hermes gateway (`hermes gateway run` / `hermes gateway stop`)
- **Service preset picker** — Segmented control to switch between OpenClaw, Hermes, and Custom service presets
- **Smart install detection** — Start scripts automatically detect and uninstall system-installed gateways (`gateway install`) before launching via `gateway run`, preventing "Gateway already running" errors
- **Dynamic service names** — All UI text updates dynamically based on selected preset (OpenClaw, Hermes, or custom)
- **Bundled shell scripts** for robust service start/stop with idempotency, multi-path binary search, timeout protection, and explicit exit codes
  - `start_openclaw.sh` / `stop_openclaw.sh`
  - `start_hermes.sh` / `stop_hermes.sh`
- **opcdesk-inspired design tokens** — Stone blue (#2A5F8A) accent, cinnabar red (#9E2A2B) for stop/error, teal green (#2E8B57) for running state
- **Chinese app name** — "Agent闹钟" displayed in Chinese locale, "AgentWaker" in English locale
- **Unit tests** — 36 test cases covering ServiceConfiguration, ServicePreset, ShellScriptResolver, ProcessInspector, and LocalizedText

### Changed

- **Project renamed** from ClawWaker to AgentWaker (English) / Agent闹钟 (Chinese)
- **Bundle identifier** changed from `bigtooth.ClawWaker` to `bigtooth.AgentWaker`
- **Process detection** switched from `pgrep -x` (exact match) to `pgrep -f` (full command line match) to properly detect interpreted scripts (Python/Node)
- **Preset switching** now resets all configuration fields (executable, arguments, stop mode, etc.) to appropriate defaults
- **Bundled script resolution** searches both `Resources/` and `Resources/Scripts/` paths for compatibility
- **Language toggle button** — Removed blue focus ring on macOS
- `OpenClawConfiguration` → `ServiceConfiguration` with preset support
- `OpenClawServiceController` → `AgentServiceController`
- `ClawWakerAppModel` → `AgentWakerAppModel`
- `ClawWakerApp` → `AgentWakerApp`
- All hardcoded "ClawWaker" references replaced with "Agent闹钟" (zh) / "AgentWaker" (en)
- Source directory renamed from `ClawWaker/` to `AgentWaker/`
- Xcode project renamed from `ClawWaker.xcodeproj` to `AgentWaker.xcodeproj`
- Version bumped from 1.1.0 to 1.2.0

### Fixed

- Hermes startup no longer fails with "Gateway already running" when `hermes gateway install` was previously used
- OpenClaw startup no longer fails with "openclaw already running" when `openclaw gateway install` was previously used
- Preset switching no longer leaves stale executable/arguments from previous preset
-bundled script URL resolution no longer fails when scripts are in `Resources/` instead of `Resources/Scripts/`

## [1.1.0] - 2026-05-02

### Added

- **Service preset system** — Switch between OpenClaw, Hermes, and Custom service presets with one click
  - OpenClaw preset: auto-configures `openclaw` / `openclaw gateway stop` with process detection for `openclaw` and `openclaw-gateway`
  - Hermes preset: auto-configures `hermes gateway run` / `hermes gateway stop` with process detection for `hermes`
  - Custom preset: manual executable path, arguments, and stop strategy configuration
- **Built-in shell scripts** for robust service start/stop with idempotency, multi-path binary search, timeout protection, and explicit exit codes
  - `start_openclaw.sh` / `stop_openclaw.sh`
  - `start_hermes.sh` / `stop_hermes.sh`
- **opcdesk-inspired design tokens** — Stone blue (#2A5F8A) accent, cinnabar red (#9E2A2B) for stop/error, teal green (#2E8B57) for running state
- **Dynamic service name** — All UI text updates dynamically based on selected preset (OpenClaw, Hermes, or custom)
- **Chinese app name** — "Agent闹钟" displayed in Chinese locale, "AgentWaker" in English locale
- **Preset picker in Settings** — Segmented control for OpenClaw / Hermes / Custom with locked fields for built-in presets

### Changed

- **Project renamed** from ClawWaker to AgentWaker (English) / Agent闹钟 (Chinese)
- **Bundle identifier** changed from `bigtooth.ClawWaker` to `bigtooth.AgentWaker`
- **Product name** changed from ClawWaker to AgentWaker
- **Logger subsystem** changed from `bigtooth.ClawWaker` to `bigtooth.AgentWaker`
- **Log directory** changed from `~/Library/Logs/ClawWaker/` to `~/Library/Logs/AgentWaker/`
- All hardcoded "OpenClaw" UI strings replaced with dynamic service names
- All hardcoded "ClawWaker" references replaced with "Agent闹钟" (zh) / "AgentWaker" (en)
- `OpenClawConfiguration` → `ServiceConfiguration` with preset support
- `OpenClawServiceController` → `AgentServiceController`
- `OpenClawConfigurationError` → `ServiceConfigurationError`
- `ClawWakerAppModel` → `AgentWakerAppModel`
- `ClawWakerApp` → `AgentWakerApp`
- `ClawWakerAppDelegate` → `AgentWakerAppDelegate`
- App window title changed from "ClawWaker" to "AgentWaker"
- Menu bar quit text changed from "Quit ClawWaker" to "Quit AgentWaker" / "退出Agent闹钟"
- Source directory renamed from `ClawWaker/` to `AgentWaker/`
- Xcode project renamed from `ClawWaker.xcodeproj` to `AgentWaker.xcodeproj`
- Version bumped from 1.0.3 to 1.1.0

## [1.0.3] - 2026-03-27

### Added
- Dynamic menu bar icon that changes based on OpenClaw running status
  - Open state icon (colored) when OpenClaw is running
  - Closed state icon (white) when OpenClaw is stopped
- Support for detecting `openclaw-gateway` process in addition to `openclaw`

### Fixed
- Improved process detection to check both `openclaw` and `openclaw-gateway` processes

## [0.1.2] - 2025-03-20

### Added
- Initial release
- Auto-start OpenClaw when display is off, power is connected, and no input for 60 seconds
- Auto-stop OpenClaw when conditions are no longer met
- Menu bar app with status monitoring
- Anti-sleep assist to keep Mac reachable while screen is off
- Chinese / English localization support
- Safe shutdown - only stops instances started by AgentWaker
