<div align="center">

<img src="./pic/cw_logo.png" alt="AgentWaker Logo" width="128" />

# AgentWaker

**Auto-manage AI agents when you step away from your Mac**

[![macOS](https://img.shields.io/badge/platform-macOS-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/bigbigtooth/AgentWaker)
[![Version](https://img.shields.io/badge/version-1.2.0-blue?style=flat-square)](https://github.com/bigbigtooth/AgentWaker)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

[**English**](./README_EN.md) · [简体中文](./README.md)

<img src="./pic/screenshot1_en.png" alt="AgentWaker Screenshot" width="80%" />

</div>

---

## Why AgentWaker?

You have one work computer. Running OpenClaw or Hermes consumes resources while you're using it, but you need it active when you step away — whether for a quick break or after heading home.

**AgentWaker automates this transition.**

## How It Works

The selected service starts automatically when **all** conditions are met:

| Condition | Description |
|:----------|:------------|
| Display off | You've left the screen |
| Power connected | Stable power supply ensured |
| No input for 60s | Confirmed absence |

When any condition breaks — display turns on, input is detected, or power disconnects — AgentWaker automatically stops the service instance it started.

Once running, you can control the service remotely via Feishu, Telegram, or other platforms.

## Built-in Service Presets

| Preset | Description |
|:----------|:------------|
| **OpenClaw** | Auto-configures `openclaw` to start and `openclaw gateway stop` to stop; detects `openclaw` processes |
| **Hermes** | Auto-configures `hermes gateway run` to start and `hermes gateway stop` to stop; detects `hermes` processes |
| **Custom** | Manually configure executable paths, arguments, and stop strategy |

## Features

- **Service Presets** — One-click switch between OpenClaw, Hermes, or custom services
- **Smart Install Detection** — Automatically detects and uninstalls system-installed gateways before launching via `gateway run`
- **Status Monitoring** — Real-time visibility of service running state and process info
- **Smart Automation** — Auto-start when away, auto-stop when back
- **Safe Shutdown** — Only stops instances started by AgentWaker; your manually launched services remain untouched
- **Menu Bar App** — Continues working in the background even when window is closed
- **Anti-Sleep Assist** — Keeps your Mac reachable while the screen is off
- **Localization** — Chinese / English support

## Quick Start

1. Download and launch AgentWaker
2. Select a service preset in Settings (OpenClaw / Hermes / Custom)
3. Keep the app running
4. Step away, plug in power, turn off screen — done

### Important Notes

> **System Service Detection**: If you previously installed a gateway as a system service via `gateway install`, AgentWaker will automatically detect and uninstall it, then launch via `gateway run` instead — ensuring it can always be stopped on demand.

> **Lid Sleep**: macOS hardware sleep policy on lid close cannot be bypassed at the application level. If you need to use your Mac with the lid closed, connect an external display and keyboard/mouse.

## Project Info

- **Version**: 1.2.0
- **Platform**: macOS
- **Repository**: [github.com/bigbigtooth/AgentWaker](https://github.com/bigbigtooth/AgentWaker)

---

<div align="center">

**[Report Bug](https://github.com/bigbigtooth/AgentWaker/issues) · [Request Feature](https://github.com/bigbigtooth/AgentWaker/issues)**

If this tool helps you, consider giving it a ⭐

</div>