import XCTest
@testable import AgentWaker

final class ServicePresetTests: XCTestCase {

    func testOpenClawProcessNames() {
        let preset = ServicePreset.openclaw
        XCTAssertTrue(preset.processNames.contains("openclaw"))
        XCTAssertEqual(preset.processNames.count, 1)
    }

    func testHermesProcessNames() {
        let preset = ServicePreset.hermes
        XCTAssertTrue(preset.processNames.contains("hermes"))
        XCTAssertEqual(preset.processNames.count, 1)
    }

    func testCustomProcessNamesIsEmpty() {
        let preset = ServicePreset.custom
        XCTAssertTrue(preset.processNames.isEmpty)
    }

    func testAllPresetsHaveDisplayName() {
        for preset in ServicePreset.allCases {
            XCTAssertFalse(preset.displayName.zh.isEmpty, "Preset \(preset.rawValue) has empty zh displayName")
            XCTAssertFalse(preset.displayName.en.isEmpty, "Preset \(preset.rawValue) has empty en displayName")
        }
    }

    func testOpenClawStartScriptName() {
        let preset = ServicePreset.openclaw
        XCTAssertEqual(preset.startScriptName, "start_openclaw.sh")
    }

    func testOpenClawStopScriptName() {
        let preset = ServicePreset.openclaw
        XCTAssertEqual(preset.stopScriptName, "stop_openclaw.sh")
    }

    func testHermesStartScriptName() {
        let preset = ServicePreset.hermes
        XCTAssertEqual(preset.startScriptName, "start_hermes.sh")
    }

    func testHermesStopScriptName() {
        let preset = ServicePreset.hermes
        XCTAssertEqual(preset.stopScriptName, "stop_hermes.sh")
    }

    func testCustomScriptNamesAreEmpty() {
        let preset = ServicePreset.custom
        XCTAssertTrue(preset.startScriptName.isEmpty)
        XCTAssertTrue(preset.stopScriptName.isEmpty)
    }

    func testDefaultExecutableOpenClaw() {
        let preset = ServicePreset.openclaw
        XCTAssertEqual(preset.defaultExecutable, "openclaw")
    }

    func testDefaultExecutableHermes() {
        let preset = ServicePreset.hermes
        XCTAssertEqual(preset.defaultExecutable, "hermes")
    }

    func testDefaultExecutableCustomIsEmpty() {
        let preset = ServicePreset.custom
        XCTAssertTrue(preset.defaultExecutable.isEmpty)
    }

    func testDefaultArgumentsOpenClaw() {
        let preset = ServicePreset.openclaw
        XCTAssertTrue(preset.defaultArguments.isEmpty)
    }

    func testDefaultArgumentsHermes() {
        let preset = ServicePreset.hermes
        XCTAssertEqual(preset.defaultArguments, "gateway run")
    }

    func testDefaultStopArgumentsOpenClaw() {
        let preset = ServicePreset.openclaw
        XCTAssertEqual(preset.defaultStopArguments, "gateway stop")
    }

    func testDefaultStopArgumentsHermes() {
        let preset = ServicePreset.hermes
        XCTAssertEqual(preset.defaultStopArguments, "gateway stop")
    }

    func testDefaultStopModeIsCommand() {
        for preset in ServicePreset.allCases {
            XCTAssertEqual(preset.defaultStopMode, .command)
        }
    }

    func testAllCasesContainsThreePresets() {
        XCTAssertEqual(ServicePreset.allCases.count, 3)
        XCTAssertEqual(ServicePreset.allCases.map(\.rawValue).sorted(), ["custom", "hermes", "openclaw"])
    }

    func testPresetIdentifiable() {
        for preset in ServicePreset.allCases {
            XCTAssertEqual(preset.id, preset.rawValue)
        }
    }
}