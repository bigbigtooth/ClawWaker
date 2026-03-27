# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Safe shutdown - only stops instances started by ClawWaker