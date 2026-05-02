import XCTest
@testable import AgentWaker

final class ProcessInspectorTests: XCTestCase {

    func testEffectiveProcessNamesForOpenClaw() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("openclaw"), "Should detect openclaw process via command line pattern")
    }

    func testEffectiveProcessNamesForHermes() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("hermes"), "Should detect hermes process")
        XCTAssertEqual(names.count, 1, "Hermes should only have one process name")
    }

    func testEffectiveProcessNamesForCustomWithFullPath() {
        let config = ServiceConfiguration(preset: .custom, executable: "/usr/local/bin/myagent", arguments: "--verbose", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("myagent"), "Should extract basename from full path")
    }

    func testEffectiveProcessNamesForCustomWithBareName() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("myagent"), "Should use bare name as-is")
    }

    func testEffectiveProcessNamesForCustomEmpty() {
        let config = ServiceConfiguration(preset: .custom, executable: "", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.isEmpty, "Empty executable should produce no process names")
    }

    func testPresetsWithMultipleProcessNamesCanStart() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        for name in config.effectiveProcessNames {
            XCTAssertFalse(name.isEmpty, "Each process name should be non-empty")
            XCTAssertFalse(name.contains("/"), "Process names for pgrep should not contain paths")
        }
    }
}