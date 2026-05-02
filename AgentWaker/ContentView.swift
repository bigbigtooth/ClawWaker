import SwiftUI

// MARK: - opcdesk-inspired design tokens
private enum DesignToken {
    static let stone = Color(red: 0.165, green: 0.373, blue: 0.541) // #2A5F8A
    static let cinnabar = Color(red: 0.620, green: 0.165, blue: 0.170) // #9E2A2B
    static let inkDeep = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    static let inkLight = Color(red: 0.400, green: 0.400, blue: 0.400) // #666666
    static let runningGreen = Color(red: 0.180, green: 0.545, blue: 0.341) // #2E8B57
    static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.92)
    static let cardBorder = Color.white.opacity(0.08)
}

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var appModel: AgentWakerAppModel

    private let dashboardColumns = [
        GridItem(.flexible(), spacing: 20, alignment: .top),
        GridItem(.flexible(), spacing: 20, alignment: .top)
    ]

    private let detectionColumns = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top)
    ]

    private var snapshot: SystemSnapshot {
        appModel.systemMonitor.snapshot
    }

    private var serviceName: LocalizedText {
        appModel.activeServiceName
    }

    private func t(_ zh: String, _ en: String) -> String {
        appModel.localized(zh: zh, en: en)
    }

    private func text(_ localizedText: LocalizedText) -> String {
        appModel.text(localizedText)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    DesignToken.stone.opacity(0.08),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection
                    overviewStrip
                    systemDetectionSection
                    LazyVGrid(columns: dashboardColumns, spacing: 20) {
                        automationSection
                        wakeSection
                    }
                    footerSection
                }
                .padding(32)
                .padding(.bottom, 88)
                .frame(maxWidth: 1280, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        appModel.toggleLanguage()
                    } label: {
                        Label(t("English", "中文"), systemImage: "globe")
                    }
                    .buttonStyle(FloatingLanguageButtonStyle())
                    .focusable(false)
                    .help(text(appModel.language.toggleDescription))
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(minWidth: 1040, minHeight: 760)
    }

    private var heroSection: some View {
        SurfaceCard(padding: 30) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(text(serviceName).uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(DesignToken.stone)

                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Image(systemName: appModel.serviceController.status.symbolName)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(appModel.serviceController.status.tint)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(text(appModel.serviceController.status.title))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                Text(heroTitle)
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(text(appModel.serviceController.activityMessage))
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 14) {
                        Button(action: primaryAction) {
                            Label(primaryActionTitle, systemImage: primaryActionSymbol)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(HeroPrimaryButtonStyle(tint: primaryActionTint))
                        .disabled(appModel.serviceController.isLaunching)

                        HStack(spacing: 10) {
                            Button {
                                appModel.refreshAll()
                            } label: {
                                Label(t("刷新状态", "Refresh"), systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(HeroSecondaryButtonStyle())

                            Button {
                                openSettings()
                            } label: {
                                Label(t("设置与日志", "Settings & Logs"), systemImage: "slider.horizontal.3")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(HeroSecondaryButtonStyle())
                        }
                    }
                    .frame(width: 320)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
                    )
                }

                HStack(spacing: 12) {
                    CompactMetricPill(
                        title: t("空闲", "Idle"),
                        value: idleLabel,
                        tint: snapshot.isIdleLongEnough ? .green : DesignToken.stone
                    )
                    CompactMetricPill(
                        title: t("防休眠", "Wake Lock"),
                        value: appModel.wakeController.isAssertionActive ? t("启用中", "Active") : t("未启用", "Inactive"),
                        tint: appModel.wakeController.isAssertionActive ? .green : .secondary
                    )
                    if let batteryLevel = snapshot.batteryLevel {
                        CompactMetricPill(
                            title: t("电量", "Battery"),
                            value: "\(batteryLevel)%",
                            tint: batteryLevel >= 50 ? DesignToken.stone : .orange
                        )
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack(spacing: 18) {
            Text(t("版本 v1.1.0", "Version v1.1.0"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://github.com/bigbigtooth/AgentWaker")!) {
                Label("GitHub", systemImage: "link")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 4)
    }

    private var overviewStrip: some View {
        HStack(spacing: 20) {
            OverviewStatCard(
                title: t("屏幕状态", "Display"),
                value: snapshot.isDisplayActive ? t("亮起", "Awake") : t("已关闭", "Dark"),
                detail: snapshot.isDisplayActive ? t("自动启动暂不触发", "Automatic start is paused for now") : t("满足自动启动关键条件", "A key automatic-start condition is satisfied"),
                systemImage: snapshot.isDisplayActive ? "display" : "moon.stars.fill",
                tint: snapshot.isDisplayActive ? DesignToken.stone : .green
            )

            OverviewStatCard(
                title: t("电源状态", "Power"),
                value: snapshot.isOnACPower ? t("已接通", "Connected") : t("未接通", "Disconnected"),
                detail: snapshot.isOnACPower ? text(snapshot.powerSourceDescription) : t("当前不满足自动启动的供电条件", "The current power state does not satisfy automatic start"),
                systemImage: snapshot.isOnACPower ? "powerplug.fill" : "battery.25",
                tint: snapshot.isOnACPower ? .green : .orange
            )

            OverviewStatCard(
                title: t("运行进程", "Processes"),
                value: "\(appModel.serviceController.runningProcesses.count)",
                detail: appModel.serviceController.runningProcesses.isEmpty ? t("当前没有检测到 \(serviceName.zh) 进程", "No \(serviceName.en) process is currently detected") : t("已发现活跃的 \(serviceName.zh) 进程", "An active \(serviceName.en) process has been detected"),
                systemImage: "terminal.fill",
                tint: appModel.serviceController.isRunning ? .green : .secondary
            )

            OverviewStatCard(
                title: t("诊断提示", "Diagnostics"),
                value: snapshot.diagnostics.isEmpty ? t("正常", "Healthy") : "\(snapshot.diagnostics.count)",
                detail: snapshot.diagnostics.isEmpty ? t("系统检测读取正常", "System readings look normal") : t("有项目需要查看设置窗口中的日志", "There are items to review in the settings logs"),
                systemImage: snapshot.diagnostics.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                tint: snapshot.diagnostics.isEmpty ? .green : .orange
            )
        }
    }

    private var systemDetectionSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("系统检测", "SYSTEM DETECTION"),
                    title: t("系统状态总览", "System Overview"),
                    description: t("将与自动启动判断相关的硬件与电源状态，整理成更适合扫读的桌面仪表板。", "A quick dashboard for the hardware and power signals that feed the automatic start decision.")
                )

                HStack(alignment: .center, spacing: 12) {
                    StatusChip(
                        title: t("电源来源", "Power Source"),
                        value: text(snapshot.powerSourceDescription),
                        systemImage: snapshot.isOnACPower ? "powerplug.fill" : "battery.50",
                        tint: snapshot.isOnACPower ? .green : .orange
                    )
                    if let batteryLevel = snapshot.batteryLevel {
                        StatusChip(
                            title: t("电池", "Battery"),
                            value: "\(batteryLevel)%",
                            systemImage: batterySymbol(for: batteryLevel),
                            tint: batteryLevel >= 50 ? DesignToken.stone : .orange
                        )
                    }
                    Spacer()
                }

                LazyVGrid(columns: detectionColumns, spacing: 16) {
                    SystemSignalTile(
                        title: t("屏幕", "Screen"),
                        value: snapshot.isDisplayActive ? t("亮起", "Awake") : t("关闭", "Dark"),
                        detail: snapshot.isDisplayActive ? t("显示器仍处于点亮状态", "The display is still on") : t("屏幕已经关闭，可触发自动化条件", "The display is dark, so automation can trigger"),
                        systemImage: snapshot.isDisplayActive ? "display" : "display.slash",
                        tint: snapshot.isDisplayActive ? DesignToken.stone : .green
                    )
                    SystemSignalTile(
                        title: t("电源", "Power"),
                        value: snapshot.isOnACPower ? t("交流电", "AC") : t("电池", "Battery"),
                        detail: snapshot.isOnACPower ? t("外接电源在线", "External power is available") : t("当前并未接通电源", "Power is not connected right now"),
                        systemImage: snapshot.isOnACPower ? "powerplug.fill" : "battery.25",
                        tint: snapshot.isOnACPower ? .green : .orange
                    )
                    SystemSignalTile(
                        title: t("充电", "Charging"),
                        value: snapshot.isCharging ? t("充电中", "Charging") : t("未充电", "Idle"),
                        detail: snapshot.isCharging ? t("电池正在充电", "The battery is charging") : t("没有进行充电", "The battery is not charging"),
                        systemImage: snapshot.isCharging ? "bolt.batteryblock.fill" : "battery.100",
                        tint: snapshot.isCharging ? .green : .secondary
                    )
                    SystemSignalTile(
                        title: t("空闲", "Idle"),
                        value: idleLabel,
                        detail: snapshot.isIdleLongEnough ? t("已超过 60 秒阈值", "The 60-second threshold has been met") : t("尚未达到自动启动的空闲阈值", "The automatic-start idle threshold has not been met"),
                        systemImage: snapshot.isIdleLongEnough ? "timer.circle.fill" : "timer",
                        tint: snapshot.isIdleLongEnough ? .green : DesignToken.stone
                    )
                    SystemSignalTile(
                        title: t("合盖", "Lid"),
                        value: snapshot.isLidClosed ? t("已合盖", "Closed") : t("已打开", "Open"),
                        detail: snapshot.isLidClosed ? t("合盖场景存在硬件级休眠限制", "Lid-closed mode still has hardware sleep limits") : t("设备保持展开状态", "The Mac stays open"),
                        systemImage: snapshot.isLidClosed ? "laptopcomputer.slash" : "laptopcomputer",
                        tint: snapshot.isLidClosed ? .orange : .green
                    )
                    SystemSignalTile(
                        title: t("防休眠断言", "Wake Assertion"),
                        value: appModel.wakeController.isAssertionActive ? t("已保持", "Held") : t("关闭", "Off"),
                        detail: text(appModel.wakeController.detail),
                        systemImage: appModel.wakeController.isAssertionActive ? "bolt.badge.clock.fill" : "bolt.slash.fill",
                        tint: appModel.wakeController.isAssertionActive ? .green : .secondary
                    )
                }
            }
        }
    }

    private var automationSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("自动化", "AUTOMATION"),
                    title: t("自动启动规则", "Automatic Start Rules"),
                    description: text(appModel.automationMessage)
                )

                StatusChip(
                    title: t("当前判断", "Current Decision"),
                    value: appModel.automationEligible ? t("条件已满足", "Eligible") : t("继续等待", "Waiting"),
                    systemImage: appModel.automationEligible ? "checkmark.circle.fill" : "hourglass.bottomhalf.filled",
                    tint: appModel.automationEligible ? .green : .orange
                )

                VStack(alignment: .leading, spacing: 12) {
                    RequirementRow(
                        title: t("屏幕已关闭", "Display is dark"),
                        detail: snapshot.isDisplayActive ? t("当前仍检测到显示器亮起", "The display is still awake") : t("已满足", "Satisfied"),
                        isMet: !snapshot.isDisplayActive
                    )
                    RequirementRow(
                        title: t("电源已接通", "Power is connected"),
                        detail: snapshot.isOnACPower ? t("已满足", "Satisfied") : t("当前为电池供电", "The Mac is currently on battery"),
                        isMet: snapshot.isOnACPower
                    )
                    RequirementRow(
                        title: t("空闲超过 60 秒", "Idle for more than 60 seconds"),
                        detail: snapshot.isIdleLongEnough ? t("已满足", "Satisfied") : t("当前空闲时长：\(idleLabel)", "Current idle time: \(idleLabel)"),
                        isMet: snapshot.isIdleLongEnough
                    )
                    RequirementRow(
                        title: t("系统检测无异常", "No blocking diagnostics"),
                        detail: snapshot.diagnostics.isEmpty ? t("已满足", "Satisfied") : t("有 \(snapshot.diagnostics.count) 条诊断提示", "\(snapshot.diagnostics.count) diagnostic item(s) need review"),
                        isMet: snapshot.diagnostics.isEmpty
                    )
                }
            }
        }
    }

    private var wakeSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("防休眠控制", "WAKE CONTROL"),
                    title: t("防休眠状态", "Wake Assertion Status"),
                    description: text(appModel.wakeLimitationNote)
                )

                StatusChip(
                    title: t("断言状态", "Assertion"),
                    value: appModel.wakeController.isAssertionActive ? t("已启用", "Enabled") : t("未启用", "Disabled"),
                    systemImage: appModel.wakeController.isAssertionActive ? "bolt.fill" : "bolt.slash",
                    tint: appModel.wakeController.isAssertionActive ? .green : .secondary
                )

                InfoCallout(
                    title: t("合盖限制提醒", "Lid-close Limitation"),
                    message: text(appModel.wakeLimitationNote),
                    tint: .orange
                )

                Button {
                    openSettings()
                } label: {
                    Label(t("在设置窗口查看睡眠建议", "View sleep guidance in Settings"), systemImage: "questionmark.circle")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var heroTitle: String {
        if appModel.serviceController.isLaunching {
            return t("正在启动 \(serviceName.zh)…", "Starting \(serviceName.en)…")
        }
        if appModel.serviceController.isRunning {
            return t("\(serviceName.zh) 正在稳定运行", "\(serviceName.en) is running normally")
        }
        if appModel.automationEligible {
            return t("系统已满足自动启动条件", "Automatic start conditions are satisfied")
        }
        return t("随时查看 \(serviceName.zh) 唤醒状态", "Monitor \(serviceName.en) wake status at a glance")
    }

    private var primaryActionTitle: String {
        appModel.serviceController.isRunning ? t("停止 \(serviceName.zh)", "Stop \(serviceName.en)") : t("启动 \(serviceName.zh)", "Start \(serviceName.en)")
    }

    private var primaryActionSymbol: String {
        appModel.serviceController.isRunning ? "stop.fill" : "play.fill"
    }

    private var idleLabel: String {
        formattedIdle(snapshot.inputIdleSeconds, language: appModel.language)
    }

    private var primaryActionTint: Color {
        appModel.serviceController.isRunning ? DesignToken.cinnabar : DesignToken.runningGreen
    }

    private func primaryAction() {
        if appModel.serviceController.isRunning {
            appModel.stopService()
        } else {
            appModel.startService()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appModel: AgentWakerAppModel
    @State private var isShowingSleepGuide = false

    private var serviceName: LocalizedText {
        appModel.activeServiceName
    }

    private func t(_ zh: String, _ en: String) -> String {
        appModel.localized(zh: zh, en: en)
    }

    private func text(_ localizedText: LocalizedText) -> String {
        appModel.text(localizedText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SurfaceCard(padding: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(t("设置与日志", "Settings & Logs"))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(t("选择服务预设或自定义命令配置，查看运行日志与诊断信息。", "Choose a service preset or custom command configuration, view runtime logs and diagnostics."))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                configurationCard
                commandActivityCard
                diagnosticsCard
                runtimeLogCard
                sleepGuidanceCard
            }
            .padding(28)
            .frame(maxWidth: 1100, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(minWidth: 940, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isShowingSleepGuide) {
            SleepGuidanceView()
                .environmentObject(appModel)
        }
    }

    private var configurationCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("服务配置", "SERVICE CONFIGURATION"),
                    title: t("服务预设与启动命令", "Service Preset & Start Commands"),
                    description: t("选择 OpenClaw、Hermes 或自定义服务。预设会自动配置启动与停止命令。", "Choose OpenClaw, Hermes, or a custom service. Presets automatically configure start and stop commands.")
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text(t("服务预设", "Service Preset"))
                        .font(.title3.weight(.semibold))

                    Picker(t("预设类型", "Preset Type"), selection: $appModel.configuration.preset) {
                        ForEach(ServicePreset.allCases) { preset in
                            Text(text(preset.displayName)).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    if appModel.configuration.preset == .custom {
                        Text(t("自定义模式下，你需要手动填写启动和停止命令。", "In custom mode, you need to fill in start and stop commands manually."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(DesignToken.stone)
                            Text(t("预设已自动配置启动与停止命令", "Preset has automatically configured start and stop commands"))
                                .font(.callout)
                                .foregroundStyle(DesignToken.stone)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DesignToken.stone.opacity(0.08))
                        )
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    SettingField(
                        title: t("启动命令", "Start Command"),
                        prompt: t("可执行文件路径或命令名", "Executable path or command name"),
                        text: $appModel.configuration.executable,
                        isDisabled: appModel.configuration.isPresetLocked
                    )
                    SettingField(
                        title: t("启动参数", "Start Arguments"),
                        prompt: t("启动参数（可选）", "Start arguments (optional)"),
                        text: $appModel.configuration.arguments,
                        isDisabled: appModel.configuration.isPresetLocked
                    )
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text(t("停止策略", "Stop Strategy"))
                        .font(.title3.weight(.semibold))

                    Picker(t("停止方式", "Stop Method"), selection: $appModel.configuration.stopMode) {
                        ForEach(StopMode.allCases) { mode in
                            Text(text(mode.title)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    SettingField(
                        title: t("停止命令", "Stop Command"),
                        prompt: t("停止命令路径或命令名（可选）", "Stop command path or name (optional)"),
                        text: $appModel.configuration.stopExecutable,
                        isDisabled: appModel.configuration.stopMode == .kill || appModel.configuration.isPresetLocked
                    )
                    SettingField(
                        title: t("停止参数", "Stop Arguments"),
                        prompt: t("停止参数（可选）", "Stop arguments (optional)"),
                        text: $appModel.configuration.stopArguments,
                        isDisabled: appModel.configuration.stopMode == .kill || appModel.configuration.isPresetLocked
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        appModel.saveConfiguration()
                    } label: {
                        Label(t("保存配置", "Save Configuration"), systemImage: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        appModel.refreshAll()
                    } label: {
                        Label(t("保存并刷新状态", "Save & Refresh"), systemImage: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                InfoCallout(
                    title: t("停止方式说明", "Stop Method Notes"),
                    message: t("可以选择执行停止命令，或者直接结束检测到的服务进程。如果启动命令执行后没有产生进程，下方日志会保留 stdout / stderr 便于排查。", "You can either run a stop command or directly terminate the detected service process. If the start command finishes without spawning a process, stdout/stderr is kept below for troubleshooting."),
                    tint: DesignToken.stone
                )
            }
        }
    }

    private var commandActivityCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("命令活动", "COMMAND ACTIVITY"),
                    title: t("命令输出与运行记录", "Command Output & Runtime"),
                    description: t("设置窗口承担详细运行信息；这样主窗口只显示概览，而排障信息不会影响扫读效率。", "Detailed runtime information lives in Settings so the main window can stay focused on the overview.")
                )

                if appModel.serviceController.runningProcesses.isEmpty {
                    EmptyStateRow(title: t("暂无运行中的进程", "No Running Processes"), message: t("当 \(serviceName.zh) 启动成功后，会在这里显示 PID 与命令行。", "When \(serviceName.en) starts successfully, its PID and command line will appear here."))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("运行中的进程", "Running Processes"))
                            .font(.title3.weight(.semibold))
                        ForEach(appModel.serviceController.runningProcesses) { process in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PID \(process.pid)")
                                    .font(.headline)
                                Text(process.command)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }

                if let record = appModel.serviceController.lastCommandRecord {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(t("最近一次命令", "Latest Command"))
                            .font(.title3.weight(.semibold))
                        DetailGrid {
                            DetailGridItem(label: t("执行时间", "Executed At"), value: formattedTimestamp(record.timestamp, language: appModel.language))
                            DetailGridItem(label: t("退出码", "Exit Code"), value: record.exitCode.map(String.init) ?? t("运行中/未返回", "Running / Pending"))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("命令行", "Command Line"))
                                .font(.headline)
                            Text(record.command)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        if !record.stdout.isEmpty {
                            CommandOutputSection(title: "stdout", content: record.stdout)
                        }
                        if !record.stderr.isEmpty {
                            CommandOutputSection(title: "stderr", content: record.stderr)
                        }
                    }
                } else {
                    EmptyStateRow(title: t("还没有命令记录", "No Command History Yet"), message: t("执行启动或停止后，这里会保存最近一次命令的摘要与输出。", "After you start or stop the service, the latest command summary and output will be kept here."))
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    eyebrow: t("诊断信息", "DIAGNOSTICS"),
                    title: t("异常与系统诊断", "Errors & Diagnostics"),
                    description: t("把错误信息、系统监测异常与恢复建议放在同一个位置，便于排查。", "Errors, monitoring issues, and recovery hints are grouped here to make troubleshooting easier.")
                )

                if let serviceError = appModel.serviceController.lastErrorMessage {
                    InfoCallout(title: t("服务层错误", "Service Error"), message: text(serviceError), tint: .orange, systemImage: "exclamationmark.triangle.fill")
                }

                if appModel.systemMonitor.snapshot.diagnostics.isEmpty {
                    InfoCallout(title: t("系统状态读取正常", "System State Looks Healthy"), message: t("没有检测到需要额外处理的系统读取问题。", "No system-reading issues were detected that need extra attention."), tint: .green, systemImage: "checkmark.seal.fill")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appModel.systemMonitor.snapshot.diagnostics, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(text(item))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    private var runtimeLogCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    SectionHeader(
                        eyebrow: t("运行日志", "RUNTIME LOGS"),
                        title: t("运行调试日志", "Runtime Debug Log"),
                        description: t("自动启动判断、系统状态变化和服务启停过程都会记录在这里，便于排查自动化问题。日志也会持久化到：\(appModel.runtimeLogStore.logFilePath)", "Automatic-start evaluations, system state changes, and service start/stop activity are recorded here for troubleshooting. Logs are also persisted to: \(appModel.runtimeLogStore.logFilePath)")
                    )
                    Spacer(minLength: 12)
                    Button(t("清空日志", "Clear Logs")) {
                        appModel.runtimeLogStore.clear()
                    }
                    .buttonStyle(.bordered)
                }

                if appModel.runtimeLogStore.entries.isEmpty {
                    EmptyStateRow(title: t("暂无调试日志", "No Runtime Logs Yet"), message: t("当系统状态变化、自动策略触发或服务启停时，这里会追加日志。", "Logs appear here when system state changes, automation triggers, or the service starts and stops."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(appModel.runtimeLogStore.entries.reversed())) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("[\(formattedTimestamp(entry.timestamp, language: appModel.language))] \(text(entry.category))")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text(text(entry.message))
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                    .frame(minHeight: 220, maxHeight: 360)
                }
            }
        }
    }

    private var sleepGuidanceCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    eyebrow: t("休眠建议", "SLEEP GUIDANCE"),
                    title: t("休眠与合盖建议", "Sleep & Lid Guidance"),
                    description: text(appModel.wakeLimitationNote)
                )

                Button {
                    isShowingSleepGuide = true
                } label: {
                    Label(t("查看关闭关屏休眠设置指引", "Open sleep-settings guidance"), systemImage: "moon.zzz.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Reusable Components

private struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(DesignToken.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(DesignToken.cardBorder, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

private struct HeroPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: tint.opacity(0.22), radius: 18, x: 0, y: 10)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct HeroSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.95 : 0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct FloatingLanguageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.95 : 0.86))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SectionHeader: View {
    let eyebrow: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(DesignToken.stone)
                .tracking(1.4)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
        .foregroundStyle(tint)
    }
}

private struct CompactMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OverviewStatCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        SurfaceCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SystemSignalTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                Spacer()
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct RequirementRow: View {
    let title: String
    let detail: String
    let isMet: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title3)
                .foregroundStyle(isMet ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct InfoCallout: View {
    let title: String
    let message: String
    let tint: Color
    var systemImage: String = "info.circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct EmptyStateRow: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SettingField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
                .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.55 : 1)
    }
}

private struct DetailGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 16) {
            content
        }
    }
}

private struct DetailGridItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CommandOutputSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .frame(minHeight: 140, maxHeight: 240)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct SleepGuidanceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AgentWakerAppModel

    private func t(_ zh: String, _ en: String) -> String {
        appModel.localized(zh: zh, en: en)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(t("关闭关屏休眠设置指引", "Display Sleep Guidance"))
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(t("为了让Agent闹钟在屏幕熄灭后尽量保持服务可达，请按下面步骤检查 macOS 设置：", "To help AgentWaker keep the service reachable after the display turns off, review these macOS settings:"))
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                GuideRow(index: 1, text: t("打开「系统设置」→「锁定屏幕」，把「接入电源适配器且显示器关闭时，关闭显示器」设置成更长时间。", "Open System Settings → Lock Screen, then make the display-off timer longer while power is connected."))
                GuideRow(index: 2, text: t("打开「系统设置」→「电池」，在「选项」里开启「接入电源时防止自动进入睡眠」（不同 macOS 文案可能略有差异）。", "Open System Settings → Battery, then enable the option that prevents automatic sleep while on power (wording varies by macOS version)."))
                GuideRow(index: 3, text: t("如果你使用合盖场景，请外接电源、显示器、键盘和鼠标；macOS 对合盖休眠有硬件级限制，软件无法完全绕过。", "If you work with the lid closed, connect power, an external display, a keyboard, and a mouse. macOS still enforces hardware-level limits around lid-closed sleep."))
                GuideRow(index: 4, text: t("也可以在终端手动验证：运行 caffeinate -dimsu，观察网络任务是否仍保持在线。", "You can also verify behavior manually in Terminal by running caffeinate -dimsu and confirming your network task stays reachable."))
            }

            InfoCallout(
                title: t("提示", "Tip"),
                message: t("Agent闹钟能阻止空闲休眠，但不能保证所有机型在合盖后依然持续联网。", "AgentWaker can prevent idle sleep, but it cannot guarantee continuous network availability on every Mac after the lid is closed."),
                tint: .orange
            )

            HStack {
                Spacer()
                Button(t("关闭", "Close")) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 620)
    }
}

private struct GuideRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 24, height: 24)
                .background(DesignToken.stone.opacity(0.12), in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

func formattedIdle(_ seconds: TimeInterval, language: AppLanguage) -> String {
    let totalSeconds = max(Int(seconds.rounded()), 0)
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60

    if minutes > 0 {
        switch language {
        case .chinese:
            return "\(minutes) 分 \(remainingSeconds) 秒"
        case .english:
            return "\(minutes)m \(remainingSeconds)s"
        }
    }
    switch language {
    case .chinese:
        return "\(remainingSeconds) 秒"
    case .english:
        return "\(remainingSeconds)s"
    }
}

private func formattedTimestamp(_ date: Date, language: AppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter.string(from: date)
}

private func batterySymbol(for level: Int) -> String {
    switch level {
    case 90...:
        return "battery.100percent"
    case 60..<90:
        return "battery.75percent"
    case 30..<60:
        return "battery.50percent"
    default:
        return "battery.25percent"
    }
}

#Preview {
    ContentView()
        .environmentObject(AgentWakerAppModel())
}
