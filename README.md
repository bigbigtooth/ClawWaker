<div align="center">

<img src="./pic/cw_logo.png" alt="AgentWaker Logo" width="128" />

# AgentWaker · Agent闹钟

**离开工位，自动唤醒 AI 智能体**

[![macOS](https://img.shields.io/badge/platform-macOS-000000?style=flat-square&logo=apple&logoColor=white)](https://github.com/bigbigtooth/AgentWaker)
[![Version](https://img.shields.io/badge/version-1.2.0-blue?style=flat-square)](https://github.com/bigbigtooth/AgentWaker)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

[English](./README_EN.md) · **简体中文**

<img src="./pic/screenshot1.png" alt="AgentWaker Screenshot" width="80%" />

</div>

---

## 为什么需要它？

你只有一台工作电脑。日常使用时，OpenClaw 或 Hermes 占用资源是个负担。但当你离开工位或下班回家，又需要它们持续运行。

**Agent闹钟让这一切自动发生。**

## 工作原理

当以下条件**同时满足**时，自动启动选定的服务：

| 条件 | 说明 |
|:-----|:-----|
| 屏幕关闭 | 你已离开显示器前 |
| 电源接通 | 确保稳定供电 |
| 60 秒无输入 | 确认你真的离开了 |

当任一条件被打破（屏幕点亮、键鼠输入、电源断开），自动停止服务。

之后，你可以通过飞书、Telegram 或其他渠道远程控制它。

## 内置服务预设

| 预设 | 说明 |
|:-----|:-----|
| **OpenClaw** | 自动配置 `openclaw` 启动与 `openclaw gateway stop` 停止，检测 `openclaw` 进程 |
| **Hermes** | 自动配置 `hermes gateway run` 启动与 `hermes gateway stop` 停止，检测 `hermes` 进程 |
| **自定义** | 手动填写可执行文件路径、参数和停止策略 |

## 功能特性

- **服务预设** — 一键切换 OpenClaw / Hermes / 自定义服务
- **智能安装检测** — 自动检测并卸载已安装为系统服务的 gateway，确保使用 `gateway run` 模式
- **状态监控** — 实时显示服务运行状态与进程信息
- **自动化规则** — 离开工位自动启动，回来自动停止
- **安全停止** — 仅停止由本应用启动的实例，不影响手动启动的服务
- **菜单栏驻留** — 关闭窗口后继续在后台工作
- **防休眠辅助** — 黑屏状态下保持设备可达
- **多语言支持** — 中文 / English

## 快速开始

1. 下载并打开 Agent闹钟（AgentWaker）
2. 在设置中选择服务预设（OpenClaw / Hermes / 自定义）
3. 保持应用运行
4. 离开工位，接上电源，关闭屏幕 — 完成

### 特别说明

> **系统服务检测**：如果你之前通过 `gateway install` 将服务注册为系统服务，Agent闹钟会在启动前自动检测并卸载，然后用 `gateway run` 方式运行，确保能随时停止。

> **合盖休眠**：macOS 的合盖硬件休眠策略无法被应用层绕过。如需合盖使用，请外接显示器和键鼠。

## 项目信息

- **版本**：1.2.0
- **平台**：macOS
- **仓库**：[github.com/bigbigtooth/AgentWaker](https://github.com/bigbigtooth/AgentWaker)

---

<div align="center">

**[反馈问题](https://github.com/bigbigtooth/AgentWaker/issues) · [功能建议](https://github.com/bigbigtooth/AgentWaker/issues)**

如果这个工具对你有帮助，欢迎 Star ⭐

</div>
