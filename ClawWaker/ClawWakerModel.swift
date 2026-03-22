import AppKit
import Combine
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import OSLog
import SwiftUI
import Darwin

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    private static let storageKey = "app.language"

    var id: String { rawValue }

    static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .chinese
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }

    var shortToggleTitle: String {
        switch self {
        case .chinese:
            return "EN"
        case .english:
            return "中文"
        }
    }

    var toggleDescription: LocalizedText {
        switch self {
        case .chinese:
            return LT("切换到英文", "Switch to English")
        case .english:
            return LT("切换到中文", "Switch to Chinese")
        }
    }

    var next: AppLanguage {
        switch self {
        case .chinese:
            return .english
        case .english:
            return .chinese
        }
    }
}

struct LocalizedText: Equatable, Hashable, Sendable {
    let zh: String
    let en: String

    func resolved(for language: AppLanguage) -> String {
        switch language {
        case .chinese:
            return zh
        case .english:
            return en
        }
    }

    static let empty = LocalizedText(zh: "", en: "")
}

@inline(__always)
func LT(_ zh: String, _ en: String) -> LocalizedText {
    LocalizedText(zh: zh, en: en)
}

struct OpenClawConfiguration: Equatable, Sendable {
    var executable: String
    var arguments: String
    var stopMode: StopMode
    var stopExecutable: String
    var stopArguments: String

    private static let executableKey = "openclaw.executable"
    private static let argumentsKey = "openclaw.arguments"
    private static let stopModeKey = "openclaw.stopMode"
    private static let stopExecutableKey = "openclaw.stopExecutable"
    private static let stopArgumentsKey = "openclaw.stopArguments"
    private static let bundledCandidates = [
        "/opt/homebrew/bin/openclaw",
        "/usr/local/bin/openclaw",
        "/usr/bin/openclaw"
    ]

    static func load(from defaults: UserDefaults = .standard) -> OpenClawConfiguration {
        let savedExecutable = defaults.string(forKey: executableKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let savedArguments = defaults.string(forKey: argumentsKey) ?? ""
        let savedStopMode = StopMode(rawValue: defaults.string(forKey: stopModeKey) ?? "") ?? .command
        let savedStopExecutable = defaults.string(forKey: stopExecutableKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let savedStopArguments = defaults.string(forKey: stopArgumentsKey) ?? ""
        return OpenClawConfiguration(
            executable: savedExecutable.isEmpty ? defaultExecutable() : savedExecutable,
            arguments: savedArguments,
            stopMode: savedStopMode,
            stopExecutable: savedStopExecutable,
            stopArguments: savedStopArguments
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(executable, forKey: Self.executableKey)
        defaults.set(arguments, forKey: Self.argumentsKey)
        defaults.set(stopMode.rawValue, forKey: Self.stopModeKey)
        defaults.set(stopExecutable, forKey: Self.stopExecutableKey)
        defaults.set(stopArguments, forKey: Self.stopArgumentsKey)
    }

    func resolvedExecutableURL() throws -> URL {
        try Self.resolveExecutable(from: executable)
    }

    func resolvedStopExecutableURL() throws -> URL? {
        let trimmed = stopExecutable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return try Self.resolveExecutable(from: trimmed)
    }

    func parsedStopArguments() throws -> [String] {
        try ShellWordsParser.parse(stopArguments)
    }

    private static func resolveExecutable(from executable: String) throws -> URL {
        let trimmed = executable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenClawConfigurationError.missingExecutable
        }

        if trimmed.contains("/") {
            let expanded = NSString(string: trimmed).expandingTildeInPath
            guard FileManager.default.isExecutableFile(atPath: expanded) else {
                throw OpenClawConfigurationError.executableNotFound(expanded)
            }
            return URL(fileURLWithPath: expanded)
        }

        let searchPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
            + Self.bundledCandidates.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }

        for directory in Array(Set(searchPaths)) where !directory.isEmpty {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(trimmed).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        throw OpenClawConfigurationError.executableNotFound(trimmed)
    }

    func parsedArguments() throws -> [String] {
        try ShellWordsParser.parse(arguments)
    }

    private static func defaultExecutable() -> String {
        bundledCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) ?? "openclaw"
    }
}

enum OpenClawConfigurationError: LocalizedError {
    case missingExecutable
    case executableNotFound(String)
    case invalidArguments(LocalizedText)

    var localizedText: LocalizedText {
        switch self {
        case .missingExecutable:
            return LT("请先填写 OpenClaw 可执行文件路径或命令名。", "Please enter the OpenClaw executable path or command name.")
        case .executableNotFound(let value):
            return LT("没有找到可执行的 OpenClaw 命令：\(value)。", "Could not find an executable OpenClaw command: \(value).")
        case .invalidArguments(let message):
            return message
        }
    }

    var errorDescription: String? {
        localizedText.zh
    }
}

private enum ShellWordsParser {
    static func parse(_ input: String) throws -> [String] {
        var arguments: [String] = []
        var current = ""
        var isEscaping = false
        var inSingleQuote = false
        var inDoubleQuote = false
        var startedArgument = false

        for character in input {
            if isEscaping {
                current.append(character)
                isEscaping = false
                startedArgument = true
                continue
            }

            if character == "\\" && !inSingleQuote {
                isEscaping = true
                startedArgument = true
                continue
            }

            if character == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                startedArgument = true
                continue
            }

            if character == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                startedArgument = true
                continue
            }

            if character.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if startedArgument {
                    arguments.append(current)
                    current = ""
                    startedArgument = false
                }
                continue
            }

            current.append(character)
            startedArgument = true
        }

        if isEscaping {
            throw OpenClawConfigurationError.invalidArguments(
                LT("参数末尾存在未完成的转义字符。", "The arguments end with an unfinished escape character.")
            )
        }

        if inSingleQuote || inDoubleQuote {
            throw OpenClawConfigurationError.invalidArguments(
                LT("参数中存在未闭合的引号。", "There is an unclosed quote in the arguments.")
            )
        }

        if startedArgument {
            arguments.append(current)
        }

        return arguments
    }
}

enum ServiceStatus: String {
    case stopped
    case running
    case error

    var title: LocalizedText {
        switch self {
        case .stopped:
            return LT("未运行", "Stopped")
        case .running:
            return LT("运行中", "Running")
        case .error:
            return LT("异常", "Error")
        }
    }

    var symbolName: String {
        switch self {
        case .stopped:
            return "stop.circle.fill"
        case .running:
            return "play.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .stopped:
            return .secondary
        case .running:
            return .green
        case .error:
            return .orange
        }
    }
}

struct RunningProcessSnapshot: Identifiable, Hashable, Sendable {
    let pid: pid_t
    let command: String

    var id: pid_t { pid }
}

struct CommandExecutionRecord: Equatable, Sendable {
    let command: String
    let stdout: String
    let stderr: String
    let exitCode: Int32?
    let timestamp: Date
}

struct RuntimeLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let category: LocalizedText
    let message: LocalizedText
}

@MainActor
final class RuntimeLogStore: ObservableObject {
    @Published private(set) var entries: [RuntimeLogEntry] = []

    private static let fileTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private let systemLogger = Logger(subsystem: "bigtooth.ClawWaker", category: "runtime")
    private let maxEntries = 400
    private let fileURL: URL

    init() {
        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("ClawWaker", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        fileURL = logsDirectory.appendingPathComponent("runtime.log")
    }

    func record(category: LocalizedText, _ message: LocalizedText) {
        let trimmedZH = message.zh.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEN = message.en.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedZH.isEmpty || !trimmedEN.isEmpty else { return }

        let trimmed = LocalizedText(
            zh: trimmedZH.isEmpty ? trimmedEN : trimmedZH,
            en: trimmedEN.isEmpty ? trimmedZH : trimmedEN
        )
        let language = AppLanguage.load()

        systemLogger.log("\(category.resolved(for: language), privacy: .public): \(trimmed.resolved(for: language), privacy: .public)")
        appendToFile(line: "[\(Self.fileTimestampFormatter.string(from: Date()))] \(category.resolved(for: language)): \(trimmed.resolved(for: language))")
        entries.append(
            RuntimeLogEntry(
                timestamp: Date(),
                category: category,
                message: trimmed
            )
        )
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func record(category: String, _ message: String) {
        let localized = LocalizedText(zh: category, en: category)
        record(category: localized, LocalizedText(zh: message, en: message))
    }

    func clear() {
        entries.removeAll()
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        systemLogger.log("Runtime logs cleared.")
    }

    var logFilePath: String {
        fileURL.path
    }

    private func appendToFile(line: String) {
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}

enum ServiceActionSource {
    case manual
    case automatic

    var label: LocalizedText {
        switch self {
        case .manual:
            return LT("手动", "manual")
        case .automatic:
            return LT("自动", "automatic")
        }
    }
}

enum StopMode: String, CaseIterable, Identifiable, Sendable {
    case command = "command"
    case kill = "kill"

    var id: String { rawValue }

    var title: LocalizedText {
        switch self {
        case .command:
            return LT("执行停止命令", "Run stop command")
        case .kill:
            return LT("直接 kill 进程", "Kill process directly")
        }
    }
}

@MainActor
final class OpenClawServiceController: ObservableObject {
    @Published private(set) var status: ServiceStatus = .stopped
    @Published private(set) var runningProcesses: [RunningProcessSnapshot] = []
    @Published private(set) var activityMessage = LT("OpenClaw 当前未运行。", "OpenClaw is not running.")
    @Published private(set) var lastErrorMessage: LocalizedText?
    @Published private(set) var isLaunching = false
    @Published private(set) var lastCommandRecord: CommandExecutionRecord?
    @Published private(set) var isManagedByApp = false

    private(set) var managedStartSource: ServiceActionSource?

    var onChange: (() -> Void)?

    private var launchedProcess: Process?
    private var refreshTimer: Timer?
    private var lastKnownConfiguration = OpenClawConfiguration.load()
    private let inspectionQueue = DispatchQueue(label: "ClawWaker.OpenClawServiceController.inspect", qos: .utility)
    private let logStore: RuntimeLogStore
    private let serviceLogCategory = LT("服务", "Service")
    private var refreshGeneration = 0
    private var pendingManagedLaunchSource: ServiceActionSource?
    private var launchDetectionDeadline: Date?
    private var launchProbeGeneration = 0

    init(logStore: RuntimeLogStore) {
        self.logStore = logStore
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshStatus(configuration: self.lastKnownConfiguration)
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var isRunning: Bool {
        !runningProcesses.isEmpty
    }

    func refreshStatus(configuration: OpenClawConfiguration) {
        lastKnownConfiguration = configuration
        refreshGeneration += 1
        let generation = refreshGeneration

        inspectionQueue.async { [configuration] in
            let result = ServiceStatusProbe.inspect(configuration: configuration)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.refreshGeneration == generation else { return }
                self.applyRefreshResult(result)
            }
        }
    }

    func start(configuration: OpenClawConfiguration, source: ServiceActionSource) {
        lastKnownConfiguration = configuration

        if !runningProcesses.isEmpty {
            status = .running
            isLaunching = false
            lastErrorMessage = nil
            activityMessage = LT("OpenClaw 已在运行，无需重复启动。", "OpenClaw is already running. No need to start it again.")
            logStore.record(
                category: serviceLogCategory,
                LT(
                    "检测到 OpenClaw 已在运行，跳过\(source.label.zh)启动。",
                    "OpenClaw is already running, skipping \(source.label.en) start."
                )
            )
            onChange?()
            return
        }

        isLaunching = true
        pendingManagedLaunchSource = source
        launchDetectionDeadline = Date().addingTimeInterval(12)
        launchProbeGeneration += 1
        activityMessage = source == .automatic
            ? LT("满足自动规则，正在启动 OpenClaw...", "Automatic conditions met. Starting OpenClaw...")
            : LT("正在启动 OpenClaw...", "Starting OpenClaw...")
        lastErrorMessage = nil
        logStore.record(
            category: serviceLogCategory,
            LT("准备\(source.label.zh)启动 OpenClaw。", "Preparing a \(source.label.en) OpenClaw start.")
        )
        onChange?()

        do {
            let executableURL = try configuration.resolvedExecutableURL()
            let arguments = try configuration.parsedArguments()
            logStore.record(
                category: serviceLogCategory,
                LT(
                    "执行启动命令：\(([executableURL.path] + arguments).joined(separator: " "))",
                    "Running start command: \(([executableURL.path] + arguments).joined(separator: " "))"
                )
            )
            recordCommand(executableURL: executableURL, arguments: arguments, stdout: "", stderr: "", exitCode: nil)
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClawWaker-openclaw-stdout-\(UUID().uuidString).log")
            let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClawWaker-openclaw-stderr-\(UUID().uuidString).log")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)

            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.standardInput = nil
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            process.environment = AppEnvironment.launchEnvironment()
            process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
            process.terminationHandler = { [weak self] process in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? outputHandle.close()
                    try? errorHandle.close()
                    let outputText = (try? String(contentsOf: outputURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorText = (try? String(contentsOf: errorURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    try? FileManager.default.removeItem(at: outputURL)
                    try? FileManager.default.removeItem(at: errorURL)
                    self.launchedProcess = nil
                    self.isLaunching = false
                    self.recordCommand(
                        executableURL: executableURL,
                        arguments: arguments,
                        stdout: outputText,
                        stderr: errorText,
                        exitCode: process.terminationStatus
                    )
                    if process.terminationStatus != 0 || !errorText.isEmpty {
                        self.pendingManagedLaunchSource = nil
                        self.launchDetectionDeadline = nil
                        let reason = errorText.isEmpty ? "进程退出，状态码 \(process.terminationStatus)。" : errorText
                        let localizedReason = errorText.isEmpty
                            ? LT("进程退出，状态码 \(process.terminationStatus)。", "The process exited with status \(process.terminationStatus).")
                            : LT(errorText, errorText)
                        self.lastErrorMessage = LT("OpenClaw 启动失败：\(localizedReason.zh)", "Failed to start OpenClaw: \(localizedReason.en)")
                        self.activityMessage = LT("OpenClaw 启动后很快退出。", "OpenClaw exited shortly after launch.")
                        self.status = .error
                        self.logStore.record(
                            category: self.serviceLogCategory,
                            LT("启动失败：\(localizedReason.zh)", "Start failed: \(localizedReason.en)")
                        )
                        self.onChange?()
                        return
                    }
                    self.logStore.record(
                        category: self.serviceLogCategory,
                        LT("启动命令已结束，继续等待 OpenClaw 进程出现。", "The start command has finished. Waiting for the OpenClaw process to appear.")
                    )
                    self.refreshStatus(configuration: self.lastKnownConfiguration)
                }
            }

            try process.run()
            launchedProcess = process
            isLaunching = false
            lastErrorMessage = nil
            activityMessage = source == .automatic
                ? LT("满足自动规则，已执行 OpenClaw 启动命令，等待进程出现。", "Automatic conditions met. Ran the OpenClaw start command and waiting for the process to appear.")
                : LT("已执行 OpenClaw 启动命令，等待进程出现。", "Ran the OpenClaw start command and waiting for the process to appear.")
            scheduleLaunchProbe(configuration: configuration, generation: launchProbeGeneration)
            onChange?()
        } catch {
            let localizedError = localizedErrorText(error)
            status = .error
            isLaunching = false
            pendingManagedLaunchSource = nil
            launchDetectionDeadline = nil
            lastErrorMessage = localizedError
            activityMessage = source == .automatic
                ? LT("自动启动 OpenClaw 失败。", "Failed to start OpenClaw automatically.")
                : LT("启动 OpenClaw 失败。", "Failed to start OpenClaw.")
            logStore.record(category: serviceLogCategory, LT("启动异常：\(localizedError.zh)", "Start error: \(localizedError.en)"))
            onChange?()
        }
    }

    func stop(configuration: OpenClawConfiguration, source: ServiceActionSource) {
        lastKnownConfiguration = configuration
        pendingManagedLaunchSource = nil
        launchDetectionDeadline = nil

        if configuration.stopMode == .command,
           let stopExecutableURL = try? configuration.resolvedStopExecutableURL() {
            do {
                logStore.record(
                    category: serviceLogCategory,
                    LT("准备通过停止命令\(source.label.zh)关闭 OpenClaw。", "Preparing to stop OpenClaw with a \(source.label.en) stop command.")
                )
                recordCommand(executableURL: stopExecutableURL, arguments: (try? configuration.parsedStopArguments()) ?? [], stdout: "", stderr: "", exitCode: nil)
                try executeStopCommand(
                    executableURL: stopExecutableURL,
                    arguments: configuration.parsedStopArguments(),
                    configuration: configuration,
                    source: source
                )
                return
            } catch {
                let localizedError = localizedErrorText(error)
                status = .error
                lastErrorMessage = localizedError
                activityMessage = LT("执行 OpenClaw 停止命令失败。", "Failed to run the OpenClaw stop command.")
                logStore.record(category: serviceLogCategory, LT("停止命令执行异常：\(localizedError.zh)", "Stop command error: \(localizedError.en)"))
                onChange?()
                return
            }
        }

        guard !runningProcesses.isEmpty else {
            isManagedByApp = false
            managedStartSource = nil
            refreshStatus(configuration: configuration)
            activityMessage = LT("OpenClaw 当前没有运行中的进程。", "There are no running OpenClaw processes.")
            logStore.record(
                category: serviceLogCategory,
                LT("收到\(source.label.zh)停止请求，但当前没有可停止的 OpenClaw 进程。", "Received a \(source.label.en) stop request, but there are no OpenClaw processes to stop.")
            )
            onChange?()
            return
        }

        let failures = runningProcesses.compactMap { process -> String? in
            if kill(process.pid, SIGTERM) == 0 {
                return nil
            }
            return "PID \(process.pid)"
        }

        if failures.isEmpty {
            isManagedByApp = false
            managedStartSource = nil
            lastErrorMessage = nil
            status = .stopped
            activityMessage = source == .automatic
                ? LT("自动策略请求停止 OpenClaw。", "Automatic policy requested OpenClaw to stop.")
                : LT("已请求停止 OpenClaw。", "Requested OpenClaw to stop.")
            logStore.record(
                category: serviceLogCategory,
                LT("已通过 kill 请求\(source.label.zh)停止 OpenClaw。", "Sent kill to stop OpenClaw from a \(source.label.en) request.")
            )
        } else {
            let joined = failures.joined(separator: ", ")
            lastErrorMessage = LT("以下进程停止失败：\(joined)。", "Failed to stop these processes: \(joined).")
            activityMessage = LT("部分 OpenClaw 进程停止失败。", "Some OpenClaw processes failed to stop.")
            status = .error
            logStore.record(category: serviceLogCategory, LT("部分进程停止失败：\(joined)。", "Some processes failed to stop: \(joined)."))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshStatus(configuration: configuration)
        }
    }

    private func executeStopCommand(
        executableURL: URL,
        arguments: [String],
        configuration: OpenClawConfiguration,
        source: ServiceActionSource
    ) throws {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClawWaker-openclaw-stop-stdout-\(UUID().uuidString).log")
        let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClawWaker-openclaw-stop-stderr-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardInput = nil
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        process.environment = AppEnvironment.launchEnvironment()
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? outputHandle.close()
                try? errorHandle.close()
                let outputText = (try? String(contentsOf: outputURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorText = (try? String(contentsOf: errorURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                try? FileManager.default.removeItem(at: outputURL)
                try? FileManager.default.removeItem(at: errorURL)
                self.recordCommand(
                    executableURL: executableURL,
                    arguments: arguments,
                    stdout: outputText,
                    stderr: errorText,
                    exitCode: process.terminationStatus
                )

                if process.terminationStatus != 0 || !errorText.isEmpty {
                    let localizedReason = errorText.isEmpty
                        ? LT("进程退出，状态码 \(process.terminationStatus)。", "The process exited with status \(process.terminationStatus).")
                        : LT(errorText, errorText)
                    self.lastErrorMessage = LT("OpenClaw 停止失败：\(localizedReason.zh)", "Failed to stop OpenClaw: \(localizedReason.en)")
                    self.activityMessage = LT("OpenClaw 停止命令执行失败。", "The OpenClaw stop command failed.")
                    self.status = .error
                    self.logStore.record(category: self.serviceLogCategory, LT("停止失败：\(localizedReason.zh)", "Stop failed: \(localizedReason.en)"))
                } else {
                    self.isManagedByApp = false
                    self.managedStartSource = nil
                    self.lastErrorMessage = nil
                    self.activityMessage = outputText.isEmpty
                        ? (source == .automatic
                            ? LT("自动策略已执行 OpenClaw 停止命令。", "Automatic policy ran the OpenClaw stop command.")
                            : LT("已执行 OpenClaw 停止命令。", "Ran the OpenClaw stop command."))
                        : LT("已执行 OpenClaw 停止命令：\(outputText)", "Ran the OpenClaw stop command: \(outputText)")
                    self.logStore.record(category: self.serviceLogCategory, LT("停止命令执行完成。", "Stop command completed."))
                }

                self.refreshStatus(configuration: configuration)
            }
        }

        try process.run()
        activityMessage = source == .automatic
            ? LT("自动策略正在执行 OpenClaw 停止命令...", "Automatic policy is running the OpenClaw stop command...")
            : LT("正在执行 OpenClaw 停止命令...", "Running the OpenClaw stop command...")
        lastErrorMessage = nil
        onChange?()
    }

    private func recordCommand(
        executableURL: URL,
        arguments: [String],
        stdout: String,
        stderr: String,
        exitCode: Int32?
    ) {
        lastCommandRecord = CommandExecutionRecord(
            command: ([executableURL.path] + arguments).joined(separator: " "),
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            timestamp: Date()
        )
    }

    private func applyRefreshResult(_ result: ServiceInspectionResult) {
        runningProcesses = result.processes

        if let errorMessage = result.errorMessage {
            status = .error
            lastErrorMessage = errorMessage
            activityMessage = LT("读取 OpenClaw 进程状态失败。", "Failed to read the OpenClaw process state.")
            logStore.record(category: serviceLogCategory, LT("刷新进程状态失败：\(errorMessage.zh)", "Failed to refresh process state: \(errorMessage.en)"))
            onChange?()
            return
        }

        if runningProcesses.isEmpty {
            if let pendingSource = pendingManagedLaunchSource,
               let deadline = launchDetectionDeadline,
               deadline > Date() {
                status = .stopped
                lastErrorMessage = nil
                let waitMessage = pendingSource == .automatic
                    ? LT("自动启动命令已执行，等待 OpenClaw 进程出现。", "Automatic start command ran. Waiting for the OpenClaw process to appear.")
                    : LT("启动命令已执行，等待 OpenClaw 进程出现。", "Start command ran. Waiting for the OpenClaw process to appear.")
                activityMessage = waitMessage
                logStore.record(category: serviceLogCategory, LT("尚未检测到 OpenClaw 进程，继续等待启动结果。", "OpenClaw is not visible yet. Continuing to wait for launch confirmation."))
                onChange?()
                return
            }

            if pendingManagedLaunchSource != nil {
                let timeoutMessage = LT("启动命令已执行，但在等待窗口内没有检测到 OpenClaw 进程。", "The start command ran, but no OpenClaw process appeared within the wait window.")
                lastErrorMessage = LT("OpenClaw 启动失败：\(timeoutMessage.zh)", "Failed to start OpenClaw: \(timeoutMessage.en)")
                activityMessage = LT("启动命令未真正拉起 OpenClaw。", "The start command did not actually launch OpenClaw.")
                status = .error
                logStore.record(category: serviceLogCategory, LT("启动超时：\(timeoutMessage.zh)", "Launch timed out: \(timeoutMessage.en)"))
            } else {
                status = .stopped
                activityMessage = LT("OpenClaw 当前未运行。", "OpenClaw is not running.")
            }
            isManagedByApp = false
            managedStartSource = nil
            pendingManagedLaunchSource = nil
            launchDetectionDeadline = nil
        } else {
            status = .running
            if let pendingSource = pendingManagedLaunchSource {
                isManagedByApp = true
                managedStartSource = pendingSource
                pendingManagedLaunchSource = nil
                launchDetectionDeadline = nil
                logStore.record(
                    category: serviceLogCategory,
                    LT("检测到 OpenClaw 进程，已标记为由 ClawWaker\(pendingSource.label.zh)启动。", "Detected an OpenClaw process and marked it as started by ClawWaker (\(pendingSource.label.en)).")
                )
            }
            lastErrorMessage = nil
            activityMessage = LT("检测到 \(runningProcesses.count) 个 OpenClaw 进程。", "Detected \(runningProcesses.count) OpenClaw process(es).")
        }

        onChange?()
    }

    private func scheduleLaunchProbe(configuration: OpenClawConfiguration, generation: Int) {
        logStore.record(category: serviceLogCategory, LT("开始轮询 OpenClaw 进程，等待启动确认。", "Started polling for the OpenClaw process while waiting for launch confirmation."))
        refreshStatus(configuration: configuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self,
                  self.launchProbeGeneration == generation,
                  self.pendingManagedLaunchSource != nil,
                  let deadline = self.launchDetectionDeadline,
                  deadline > Date(),
                  !self.isRunning else { return }
            self.scheduleLaunchProbe(configuration: configuration, generation: generation)
        }
    }
}

enum ProcessInspectionError: LocalizedError {
    case processListFailed(String)

    var localizedText: LocalizedText {
        switch self {
        case .processListFailed(let output):
            return LT("读取系统进程列表失败：\(output)", "Failed to read the system process list: \(output)")
        }
    }

    var errorDescription: String? {
        localizedText.zh
    }
}

private func localizedErrorText(_ error: Error) -> LocalizedText {
    if let error = error as? OpenClawConfigurationError {
        return error.localizedText
    }
    if let error = error as? ProcessInspectionError {
        return error.localizedText
    }
    return LT(error.localizedDescription, error.localizedDescription)
}

private enum ProcessInspector {
    private static let knownExecutableBasenames: Set<String> = [
        "openclaw"
    ]

    static func matchingProcesses(configuration: OpenClawConfiguration) throws -> [RunningProcessSnapshot] {
        let resolvedPath = try? configuration.resolvedExecutableURL().path
        let requestedExecutable = configuration.executable.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedBasename = URL(fileURLWithPath: requestedExecutable).lastPathComponent
        let resolvedBasename = resolvedPath.map { URL(fileURLWithPath: $0).lastPathComponent }
        let candidateNames = Set([requestedBasename, resolvedBasename].compactMap { $0 }.filter { !$0.isEmpty })
            .union(knownExecutableBasenames)
        var seenPIDs = Set<pid_t>()
        var matches: [RunningProcessSnapshot] = []

        for executableName in candidateNames.sorted() {
            let pgrepResult = try CommandRunner.run(
                executablePath: "/usr/bin/pgrep",
                arguments: ["-x", executableName]
            )

            let pidOutput: String
            switch pgrepResult.exitCode {
            case 0:
                pidOutput = pgrepResult.stdout
            case 1:
                pidOutput = ""
            default:
                throw ProcessInspectionError.processListFailed(
                    pgrepResult.stderr.isEmpty ? pgrepResult.stdout : pgrepResult.stderr
                )
            }

            let pids = pidOutput
                .split(whereSeparator: \.isNewline)
                .compactMap { pid_t(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }

            for pid in pids where !seenPIDs.contains(pid) {
                guard let snapshot = try processSnapshot(for: pid) else {
                    continue
                }
                seenPIDs.insert(pid)
                matches.append(snapshot)
            }
        }

        return matches.sorted { $0.pid < $1.pid }
    }

    private static func processSnapshot(for pid: pid_t) throws -> RunningProcessSnapshot? {
        let output = try CommandRunner.capture(
            executablePath: "/bin/ps",
            arguments: ["-p", String(pid), "-o", "pid=,command="]
        )

        let line = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        guard let line else {
            return nil
        }

        let components = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
        guard components.count == 2, let parsedPID = pid_t(components[0]) else {
            return nil
        }

        let command = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.contains("ClawWaker.app") else {
            return nil
        }

        return RunningProcessSnapshot(pid: parsedPID, command: command)
    }
}

private struct ServiceInspectionResult: Sendable {
    let processes: [RunningProcessSnapshot]
    let errorMessage: LocalizedText?
}

private enum ServiceStatusProbe {
    static func inspect(configuration: OpenClawConfiguration) -> ServiceInspectionResult {
        do {
            return ServiceInspectionResult(
                processes: try ProcessInspector.matchingProcesses(configuration: configuration),
                errorMessage: nil
            )
        } catch {
            return ServiceInspectionResult(
                processes: [],
                errorMessage: localizedErrorText(error)
            )
        }
    }
}

private enum CommandRunner {
    static func capture(executablePath: String, arguments: [String]) throws -> String {
        let result = try run(executablePath: executablePath, arguments: arguments)
        guard result.exitCode == 0 else {
            throw ProcessInspectionError.processListFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        return result.stdout
    }

    static func run(executablePath: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: outputData, as: UTF8.self)
        let errorOutput = String(decoding: errorData, as: UTF8.self)

        return CommandResult(stdout: output, stderr: errorOutput, exitCode: process.terminationStatus)
    }
}

private struct CommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

private enum AppEnvironment {
    static func launchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let preferredPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existingPaths = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        var mergedPaths: [String] = []

        for path in preferredPaths + existingPaths where !path.isEmpty && !mergedPaths.contains(path) {
            mergedPaths.append(path)
        }

        environment["PATH"] = mergedPaths.joined(separator: ":")
        environment["HOME"] = environment["HOME"] ?? NSHomeDirectory()
        return environment
    }
}

struct SystemSnapshot: Equatable {
    var isDisplayActive = true
    var isOnACPower = false
    var isCharging = false
    var powerSourceDescription = LT("未知", "Unknown")
    var batteryLevel: Int?
    var inputIdleSeconds: TimeInterval = 0
    var isLidClosed = false
    var diagnostics: [LocalizedText] = []

    var isIdleLongEnough: Bool {
        inputIdleSeconds >= 60
    }
}

@MainActor
final class SystemStateMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot()

    var onChange: (() -> Void)?

    private var refreshTimer: Timer?
    private let logStore: RuntimeLogStore
    private let systemLogCategory = LT("系统", "System")
    private var displayStateOverride: Bool?
    private var hasLoggedDisplayProbeFallback = false

    init(logStore: RuntimeLogStore) {
        self.logStore = logStore
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        let previous = snapshot
        var diagnostics: [LocalizedText] = []

        let displayActive = Self.readDisplayState() ?? {
            if !hasLoggedDisplayProbeFallback {
                logStore.record(category: systemLogCategory, LT("无法直接读取屏幕电源状态，改用通知维护的屏幕状态。", "Could not read the display power state directly, so ClawWaker is using the notification-maintained display state instead."))
                hasLoggedDisplayProbeFallback = true
            }
            return displayStateOverride ?? previous.isDisplayActive
        }()

        let powerDetails = Self.readPowerDetails() ?? {
            diagnostics.append(LT("无法读取当前电源与充电状态。", "Could not read the current power and charging state."))
            return PowerDetails(
                isOnACPower: previous.isOnACPower,
                isCharging: previous.isCharging,
                powerSourceDescription: previous.powerSourceDescription,
                batteryLevel: previous.batteryLevel
            )
        }()

        let inputIdleSeconds = Self.readInputIdleSeconds() ?? {
            diagnostics.append(LT("无法读取最近的鼠标键盘空闲时间。", "Could not read the recent keyboard and mouse idle time."))
            return previous.inputIdleSeconds
        }()

        let lidClosed = Self.readLidClosedState() ?? {
            diagnostics.append(LT("无法读取合盖状态。", "Could not read the lid-closed state."))
            return previous.isLidClosed
        }()

        let updated = SystemSnapshot(
            isDisplayActive: displayActive,
            isOnACPower: powerDetails.isOnACPower,
            isCharging: powerDetails.isCharging,
            powerSourceDescription: powerDetails.powerSourceDescription,
            batteryLevel: powerDetails.batteryLevel,
            inputIdleSeconds: inputIdleSeconds,
            isLidClosed: lidClosed,
            diagnostics: diagnostics
        )

        guard updated != snapshot else {
            return
        }

        snapshot = updated
        logStore.record(
            category: systemLogCategory,
            LT(
                "状态更新：屏幕\(updated.isDisplayActive ? "亮起" : "关闭")，电源\(updated.isOnACPower ? "已接通" : "未接通")，充电\(updated.isCharging ? "是" : "否")，空闲\(Int(updated.inputIdleSeconds.rounded()))秒。",
                "State updated: display \(updated.isDisplayActive ? "awake" : "dark"), power \(updated.isOnACPower ? "connected" : "disconnected"), charging \(updated.isCharging ? "yes" : "no"), idle \(Int(updated.inputIdleSeconds.rounded()))s."
            )
        )
        if !diagnostics.isEmpty {
            let zh = diagnostics.map(\.zh).joined(separator: "；")
            let en = diagnostics.map(\.en).joined(separator: "; ")
            logStore.record(category: systemLogCategory, LT("检测告警：\(zh)", "Diagnostics warning: \(en)"))
        }
        onChange?()
    }

    func setDisplayStateOverride(isActive: Bool, source: LocalizedText) {
        displayStateOverride = isActive
        logStore.record(
            category: systemLogCategory,
            LT(
                "收到屏幕状态通知：\(source.zh)，已记录为屏幕\(isActive ? "亮起" : "关闭")。",
                "Received display state notification: \(source.en). Recorded the display as \(isActive ? "awake" : "dark")."
            )
        )
        refresh()
    }

    private static func readDisplayState() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayWrangler"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, "CurrentPowerState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }

        if let number = property as? NSNumber {
            return number.intValue > 3
        }

        return nil
    }

    private static func readPowerDetails() -> PowerDetails? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return nil
        }

        guard let powerSourceList = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let providedSource = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? else {
            return nil
        }

        let descriptions = powerSourceList.compactMap { source -> [String: Any]? in
            IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        }
        let internalBattery = descriptions.first {
            ($0[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String)
        }

        let isOnACPower = providedSource == (kIOPSACPowerValue as String)
        let isCharging = internalBattery?[kIOPSIsChargingKey as String] as? Bool ?? false
        let currentCapacity = internalBattery?[kIOPSCurrentCapacityKey as String] as? Int
        let maxCapacity = internalBattery?[kIOPSMaxCapacityKey as String] as? Int
        let batteryLevel: Int? = {
            guard let currentCapacity, let maxCapacity, maxCapacity > 0 else { return nil }
            return Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
        }()

        let description: LocalizedText
        if isCharging {
            description = LT("已接通电源，正在充电", "Power connected, charging")
        } else if isOnACPower {
            description = batteryLevel == 100
                ? LT("已接通电源，已充满", "Power connected, fully charged")
                : LT("已接通电源，当前未充电", "Power connected, not charging")
        } else {
            description = LT("当前使用电池供电", "Running on battery")
        }

        return PowerDetails(
            isOnACPower: isOnACPower,
            isCharging: isCharging,
            powerSourceDescription: description,
            batteryLevel: batteryLevel
        )
    }

    private static func readInputIdleSeconds() -> TimeInterval? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }

        if let number = property as? NSNumber {
            return number.doubleValue / 1_000_000_000
        }

        if let data = property as? Data {
            return data.withUnsafeBytes { rawBuffer in
                guard let baseAddress = rawBuffer.baseAddress else { return nil }
                let value = baseAddress.assumingMemoryBound(to: UInt64.self).pointee
                return Double(value) / 1_000_000_000
            }
        }

        return nil
    }

    private static func readLidClosedState() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let property = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }

        if let number = property as? NSNumber {
            return number.boolValue
        }

        if let boolean = property as? Bool {
            return boolean
        }

        return nil
    }
}

@MainActor
final class WakeAssertionController: ObservableObject {
    @Published private(set) var isAssertionActive = false
    @Published private(set) var detail = LT("未申请防休眠断言。", "No wake assertion is currently active.")

    private var assertionID: IOPMAssertionID = 0

    func setActive(_ shouldBeActive: Bool, reason: String) {
        if shouldBeActive && !isAssertionActive {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason as CFString,
                &assertionID
            )

            if result == kIOReturnSuccess {
                isAssertionActive = true
                detail = LT("已阻止系统因空闲而休眠，显示器仍可关闭。", "Preventing idle system sleep while still allowing the display to turn off.")
            } else {
                detail = LT("申请防休眠断言失败，错误码 \(result)。", "Failed to acquire a wake assertion. Error code: \(result).")
            }
            return
        }

        if !shouldBeActive && isAssertionActive {
            releaseAssertion()
        }
    }

    func releaseAssertion() {
        guard isAssertionActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isAssertionActive = false
        detail = LT("未申请防休眠断言。", "No wake assertion is currently active.")
    }
}

@MainActor
final class ClawWakerAppModel: ObservableObject {
    @Published var language: AppLanguage
    @Published var configuration: OpenClawConfiguration
    @Published private(set) var automationMessage = LT("等待系统状态更新。", "Waiting for the system state to update.")
    @Published private(set) var wakeLimitationNote = LT("通过公开 API 可以阻止空闲休眠，但无法可靠地绕过合盖后的硬件休眠。", "Public APIs can prevent idle sleep, but they cannot reliably bypass hardware sleep after the lid is closed.")

    let runtimeLogStore: RuntimeLogStore
    let serviceController: OpenClawServiceController
    let systemMonitor: SystemStateMonitor
    let wakeController: WakeAssertionController

    private var manualAutoStartSuppressedUntilReset = false
    private var autoStopIssuedUntilReset = false
    private var nextAutoStartAllowedAt = Date.distantPast
    private var cancellables: Set<AnyCancellable> = []
    private let automationLogCategory = LT("自动化", "Automation")
    private let systemLogCategory = LT("系统", "System")

    init() {
        let runtimeLogStore = RuntimeLogStore()
        self.runtimeLogStore = runtimeLogStore
        self.serviceController = OpenClawServiceController(logStore: runtimeLogStore)
        self.systemMonitor = SystemStateMonitor(logStore: runtimeLogStore)
        self.wakeController = WakeAssertionController()
        language = AppLanguage.load()
        configuration = OpenClawConfiguration.load()
        serviceController.$status
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.$runningProcesses
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.$activityMessage
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.$lastErrorMessage
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.$isLaunching
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.$isManagedByApp
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        runtimeLogStore.$entries
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        systemMonitor.$snapshot
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        wakeController.$isAssertionActive
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        wakeController.$detail
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        serviceController.onChange = { [weak self] in
            self?.reconcileState(trigger: "service")
        }
        systemMonitor.onChange = { [weak self] in
            self?.reconcileState(trigger: "system")
        }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.systemMonitor.setDisplayStateOverride(isActive: false, source: LT("屏幕已进入睡眠", "Display went to sleep"))
                self.serviceController.refreshStatus(configuration: self.configuration)
                self.reconcileState(trigger: "screen-sleep")
            }
            .store(in: &cancellables)
        workspaceCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.systemMonitor.setDisplayStateOverride(isActive: true, source: LT("屏幕已唤醒", "Display woke"))
                self.serviceController.refreshStatus(configuration: self.configuration)
                self.reconcileState(trigger: "screen-wake")
            }
            .store(in: &cancellables)
        workspaceCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.runtimeLogStore.record(category: self?.systemLogCategory ?? LT("系统", "System"), LT("收到系统通知：Mac 已从睡眠中唤醒。", "Received a system notification that the Mac woke from sleep."))
                self?.refreshAll()
            }
            .store(in: &cancellables)

        runtimeLogStore.record(category: automationLogCategory, LT("ClawWaker 已启动，开始监听系统状态。", "ClawWaker started and is now monitoring system state."))
        refreshAll()
    }

    var automationEligible: Bool {
        let snapshot = systemMonitor.snapshot
        return !snapshot.isDisplayActive
            && snapshot.isOnACPower
            && snapshot.isIdleLongEnough
    }

    var statusBarSymbolName: String {
        if serviceController.status == .running {
            return "bolt.horizontal.circle.fill"
        }
        if automationEligible {
            return "moon.zzz.fill"
        }
        if serviceController.status == .error || !systemMonitor.snapshot.diagnostics.isEmpty {
            return "exclamationmark.triangle.fill"
        }
        return "bolt.horizontal.circle"
    }

    func localized(zh: String, en: String) -> String {
        LT(zh, en).resolved(for: language)
    }

    func text(_ localizedText: LocalizedText) -> String {
        localizedText.resolved(for: language)
    }

    func toggleLanguage() {
        language = language.next
        language.save()
    }

    func refreshAll() {
        configuration.save()
        runtimeLogStore.record(category: automationLogCategory, LT("收到刷新请求，重新读取系统状态与 OpenClaw 进程。", "Received a refresh request. Re-reading system state and OpenClaw processes."))
        systemMonitor.refresh()
        serviceController.refreshStatus(configuration: configuration)
        reconcileState(trigger: "manual-refresh")
    }

    func saveConfiguration() {
        configuration.save()
        runtimeLogStore.record(category: automationLogCategory, LT("已保存 OpenClaw 配置。", "Saved the OpenClaw configuration."))
        serviceController.refreshStatus(configuration: configuration)
        reconcileState(trigger: "configuration")
    }

    func startService() {
        configuration.save()
        manualAutoStartSuppressedUntilReset = false
        nextAutoStartAllowedAt = Date.distantPast
        runtimeLogStore.record(category: automationLogCategory, LT("用户手动请求启动 OpenClaw。", "The user manually requested OpenClaw to start."))
        serviceController.start(configuration: configuration, source: .manual)
        reconcileState(trigger: "manual-start")
    }

    func stopService() {
        if automationEligible {
            manualAutoStartSuppressedUntilReset = true
            runtimeLogStore.record(category: automationLogCategory, LT("用户在自动条件满足时手动停止 OpenClaw，本轮条件内暂停自动启动。", "The user manually stopped OpenClaw while automatic conditions were satisfied, so auto-start is paused until the conditions reset."))
        } else {
            runtimeLogStore.record(category: automationLogCategory, LT("用户手动请求停止 OpenClaw。", "The user manually requested OpenClaw to stop."))
        }
        serviceController.stop(configuration: configuration, source: .manual)
        reconcileState(trigger: "manual-stop")
    }

    private func reconcileState(trigger: String) {
        let snapshot = systemMonitor.snapshot
        let isEligible = automationEligible
        if snapshot.isLidClosed {
            wakeLimitationNote = LT("检测到合盖；ClawWaker 会继续申请防休眠断言，但 macOS 公开接口无法保证合盖后仍保持联网唤醒。", "The lid appears closed. ClawWaker will keep requesting a wake assertion, but public macOS APIs cannot guarantee network wakefulness after the lid is closed.")
        } else {
            wakeLimitationNote = LT("已支持显示器黑屏时阻止空闲休眠；如果合上屏幕，系统仍可能因为硬件策略进入睡眠。", "Idle sleep prevention works while the display is dark, but the system may still sleep because of hardware policy when the lid is closed.")
        }

        if !isEligible {
            manualAutoStartSuppressedUntilReset = false
            nextAutoStartAllowedAt = Date.distantPast
        }

        if isEligible || !serviceController.isRunning || serviceController.managedStartSource != .automatic {
            autoStopIssuedUntilReset = false
        }

        let shouldKeepAwake = isEligible || (serviceController.isRunning && serviceController.isManagedByApp)
        wakeController.setActive(shouldKeepAwake, reason: "ClawWaker keeps OpenClaw reachable while the display sleeps.")

        let now = Date()
        let cooldownRemaining = max(0, nextAutoStartAllowedAt.timeIntervalSince(now))
        runtimeLogStore.record(
            category: automationLogCategory,
            LT(
                "状态评估（触发源：\(trigger)）：屏幕\(snapshot.isDisplayActive ? "亮起" : "关闭")，电源\(snapshot.isOnACPower ? "已接通" : "未接通")，空闲\(Int(snapshot.inputIdleSeconds.rounded()))秒，条件\(isEligible ? "满足" : "不满足")，运行中=\(serviceController.isRunning ? "是" : "否")，启动中=\(serviceController.isLaunching ? "是" : "否")，手动抑制=\(manualAutoStartSuppressedUntilReset ? "是" : "否")，重试冷却=\(cooldownRemaining > 0 ? "\(Int(cooldownRemaining.rounded()))秒" : "无")。",
                "State evaluation (trigger: \(trigger)): display \(snapshot.isDisplayActive ? "awake" : "dark"), power \(snapshot.isOnACPower ? "connected" : "disconnected"), idle \(Int(snapshot.inputIdleSeconds.rounded()))s, eligible \(isEligible ? "yes" : "no"), running=\(serviceController.isRunning ? "yes" : "no"), launching=\(serviceController.isLaunching ? "yes" : "no"), manual suppression=\(manualAutoStartSuppressedUntilReset ? "yes" : "no"), retry cooldown=\(cooldownRemaining > 0 ? "\(Int(cooldownRemaining.rounded()))s" : "none")."
            )
        )

        if !isEligible
            && serviceController.isRunning
            && serviceController.managedStartSource == .automatic
            && !autoStopIssuedUntilReset {
            autoStopIssuedUntilReset = true
            automationMessage = LT("自动停止条件触发，正在关闭由 ClawWaker 启动的 OpenClaw。", "Auto-stop conditions were triggered. Stopping the OpenClaw instance started by ClawWaker.")
            runtimeLogStore.record(category: automationLogCategory, LT("检测到自动条件被破坏，准备停止由 ClawWaker 自动启动的 OpenClaw。", "Automatic conditions were broken. Preparing to stop the OpenClaw instance started automatically by ClawWaker."))
            serviceController.stop(configuration: configuration, source: .automatic)
            return
        }

        if isEligible
            && !serviceController.isRunning
            && !serviceController.isLaunching
            && !manualAutoStartSuppressedUntilReset
            && now >= nextAutoStartAllowedAt {
            nextAutoStartAllowedAt = now.addingTimeInterval(10)
            automationMessage = LT("满足自动启动条件，正在尝试启动 OpenClaw。", "Automatic start conditions are met. Trying to start OpenClaw.")
            runtimeLogStore.record(category: automationLogCategory, LT("自动启动条件满足，开始尝试启动 OpenClaw。", "Automatic start conditions are satisfied. Beginning to start OpenClaw."))
            serviceController.start(configuration: configuration, source: .automatic)
            return
        }

        if !snapshot.diagnostics.isEmpty {
            let zh = snapshot.diagnostics.map(\.zh).joined(separator: "；")
            let en = snapshot.diagnostics.map(\.en).joined(separator: "; ")
            runtimeLogStore.record(category: automationLogCategory, LT("系统存在附加诊断信息：\(zh)。这些信息不再阻止自动启动。", "Additional diagnostics are present: \(en). They no longer block automatic start."))
        }

        if isEligible {
            if trigger == "manual-stop" && !serviceController.isRunning {
                automationMessage = LT("你已手动停止 OpenClaw；自动启动会等条件重置后再恢复。", "You manually stopped OpenClaw. Automatic start will resume after the conditions reset.")
                return
            }
            automationMessage = serviceController.isRunning
                ? LT("自动规则已满足，OpenClaw 当前处于运行中。", "Automatic rules are satisfied and OpenClaw is currently running.")
                : LT("自动规则已满足，等待启动或人工干预。", "Automatic rules are satisfied. Waiting for launch or manual intervention.")
            return
        }

        let inputIdle = Int(snapshot.inputIdleSeconds.rounded())
        let displayMessage = snapshot.isDisplayActive
            ? LT("屏幕亮起", "display awake")
            : LT("屏幕已关闭", "display dark")
        let powerMessage = snapshot.powerSourceDescription
        let idleMessage = snapshot.isIdleLongEnough
            ? LT("已空闲 \(inputIdle) 秒", "idle for \(inputIdle)s")
            : LT("空闲 \(inputIdle) 秒，尚未达到 60 秒", "idle for \(inputIdle)s, below the 60-second threshold")
        automationMessage = LT(
            "自动策略等待中：\(displayMessage.zh)、\(powerMessage.zh)、\(idleMessage.zh)。",
            "Automatic policy is waiting: \(displayMessage.en), \(powerMessage.en), \(idleMessage.en)."
        )

    }
}

private struct PowerDetails: Equatable {
    let isOnACPower: Bool
    let isCharging: Bool
    let powerSourceDescription: LocalizedText
    let batteryLevel: Int?
}
