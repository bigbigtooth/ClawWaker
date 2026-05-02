import XCTest
@testable import AgentWaker

final class LocalizedTextTests: XCTestCase {

    func testServicePresetChineseDisplayNames() {
        XCTAssertEqual(ServicePreset.openclaw.displayName.zh, "OpenClaw")
        XCTAssertEqual(ServicePreset.hermes.displayName.zh, "Hermes")
        XCTAssertEqual(ServicePreset.custom.displayName.zh, "自定义")
    }

    func testServicePresetEnglishDisplayNames() {
        XCTAssertEqual(ServicePreset.openclaw.displayName.en, "OpenClaw")
        XCTAssertEqual(ServicePreset.hermes.displayName.en, "Hermes")
        XCTAssertEqual(ServicePreset.custom.displayName.en, "Custom")
    }

    func testActiveServiceNameOpenClawPreset() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        XCTAssertEqual(config.activeServiceName.zh, "OpenClaw")
        XCTAssertEqual(config.activeServiceName.en, "OpenClaw")
    }

    func testActiveServiceNameHermesPreset() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        XCTAssertEqual(config.activeServiceName.zh, "Hermes")
        XCTAssertEqual(config.activeServiceName.en, "Hermes")
    }

    func testActiveServiceNameCustomPreset() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertEqual(config.activeServiceName.zh, "自定义")
        XCTAssertEqual(config.activeServiceName.en, "Custom")
    }

    func testActiveServiceNameCustomPresetWithExecutable() {
        let config = ServiceConfiguration(preset: .custom, executable: "/usr/local/bin/special-agent", arguments: "--port 8080", stopMode: .command, stopExecutable: "/usr/local/bin/special-agent", stopArguments: "--stop")
        XCTAssertEqual(config.activeServiceName.zh, "自定义")
        XCTAssertEqual(config.activeServiceName.en, "Custom")
    }

    func testAllPresetsHaveNonEmptyDisplayNames() {
        for preset in ServicePreset.allCases {
            XCTAssertFalse(preset.displayName.zh.isEmpty)
            XCTAssertFalse(preset.displayName.en.isEmpty)
        }
    }

    func testStopModeDisplayNames() {
        XCTAssertEqual(StopMode.command.title.zh, "执行停止命令")
        XCTAssertEqual(StopMode.command.title.en, "Run stop command")
        XCTAssertEqual(StopMode.kill.title.zh, "直接 kill 进程")
        XCTAssertEqual(StopMode.kill.title.en, "Kill process directly")
    }
}