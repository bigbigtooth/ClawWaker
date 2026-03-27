import AppKit
import SwiftUI

private let dashboardStartupSize = NSSize(width: 1344, height: 820)

@main
struct ClawWakerApp: App {
    @NSApplicationDelegateAdaptor(ClawWakerAppDelegate.self) private var appDelegate
    @StateObject private var appModel: ClawWakerAppModel
    private let dashboardWindowController: DashboardWindowController

    init() {
        let model = ClawWakerAppModel()
        _appModel = StateObject(wrappedValue: model)
        dashboardWindowController = DashboardWindowController(appModel: model)
        appDelegate.appModel = model
    }

    var body: some Scene {
        WindowGroup("ClawWaker") {
            ContentView()
                .environmentObject(appModel)
        }
        .defaultSize(width: dashboardStartupSize.width, height: dashboardStartupSize.height)

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }

        MenuBarExtra("ClawWaker", image: appModel.serviceController.isRunning ? "MenuBarIconOpen" : "MenuBarIconClose") {
            MenuBarContentView(serviceController: appModel.serviceController) {
                openDashboard()
            }
            .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }

    private func openDashboard() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let existingWindow = NSApplication.shared.windows.first(where: { $0.title == "ClawWaker" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        dashboardWindowController.show()
    }
}

final class ClawWakerAppDelegate: NSObject, NSApplicationDelegate {
    weak var appModel: ClawWakerAppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: false)
        appModel?.runtimeLogStore.record(
            category: LT("应用", "App"),
            LT("应用启动完成；即使关闭所有窗口，后台自动策略仍会继续运行。", "App launch completed. Even if all windows close, the background automation policy will keep running.")
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if NSApplication.shared.activationPolicy() != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }
    }
}

private struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var appModel: ClawWakerAppModel
    @ObservedObject var serviceController: OpenClawServiceController
    let openDashboard: () -> Void

    private func t(_ zh: String, _ en: String) -> String {
        appModel.localized(zh: zh, en: en)
    }

    private func text(_ localizedText: LocalizedText) -> String {
        appModel.text(localizedText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenClaw")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(t("服务状态", "Service Status"))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 8, height: 8)
                    Text(menuStatusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule(style: .continuous).fill(menuStatusColor))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Divider()

            menuActionButton(
                title: serviceController.isRunning ? t("停止 OpenClaw", "Stop OpenClaw") : t("启动 OpenClaw", "Start OpenClaw"),
                systemImage: serviceController.isRunning ? "stop.fill" : "play.fill"
            ) {
                if serviceController.isRunning {
                    appModel.stopService()
                } else {
                    appModel.startService()
                }
            }
            .disabled(serviceController.isLaunching)

            menuActionButton(title: t("打开主窗口", "Open Dashboard"), systemImage: "macwindow") {
                openDashboard()
            }

            menuActionButton(title: t("打开设置", "Open Settings"), systemImage: "gearshape") {
                openSettings()
            }

            menuActionButton(
                title: text(appModel.language.toggleDescription),
                systemImage: "globe"
            ) {
                appModel.toggleLanguage()
            }

            Divider()

            menuActionButton(title: t("退出 ClawWaker", "Quit ClawWaker"), systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 260)
        .padding(14)
    }

    private var menuStatusText: String {
        if serviceController.isLaunching {
            return t("启动中", "Starting")
        }
        return text(serviceController.status.title)
    }

    private var menuStatusColor: Color {
        if serviceController.isLaunching {
            return .orange
        }
        switch serviceController.status {
        case .running:
            return Color(red: 0.05, green: 0.6, blue: 0.24)
        case .stopped:
            return Color(red: 0.78, green: 0.15, blue: 0.18)
        case .error:
            return Color(red: 0.78, green: 0.15, blue: 0.18)
        }
    }

    private func menuActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private final class DashboardWindowController {
    private let appModel: ClawWakerAppModel
    private var window: NSWindow?

    init(appModel: ClawWakerAppModel) {
        self.appModel = appModel
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let rootView = ContentView()
            .environmentObject(appModel)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClawWaker"
        window.setContentSize(dashboardStartupSize)
        window.minSize = NSSize(width: 1040, height: 760)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }
}
