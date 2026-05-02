import XCTest
@testable import AgentWaker

final class ServiceConfigurationTests: XCTestCase {

    private let defaults = UserDefaults(suiteName: "ServiceConfigurationTests")!

    override func setUp() {
        defaults.removePersistentDomain(forName: "ServiceConfigurationTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "ServiceConfigurationTests")
    }

    func testDefaultPresetIsOpenClaw() {
        let config = ServiceConfiguration.load(from: defaults)
        XCTAssertEqual(config.preset, .openclaw)
    }

    func testOpenClawPresetProcessNames() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("openclaw"))
    }

    func testHermesPresetProcessNames() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("hermes"))
        XCTAssertEqual(names.count, 1)
    }

    func testCustomPresetProcessNamesFromExecutable() {
        let config = ServiceConfiguration(preset: .custom, executable: "/usr/local/bin/myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("myagent"))
    }

    func testCustomPresetBareExecutableProcessNames() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.contains("myagent"))
    }

    func testCustomPresetEmptyExecutableProcessNames() {
        let config = ServiceConfiguration(preset: .custom, executable: "", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let names = config.effectiveProcessNames
        XCTAssertTrue(names.isEmpty)
    }

    func testOpenClawPresetIsLocked() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "")
        XCTAssertTrue(config.isPresetLocked)
    }

    func testHermesPresetIsLocked() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        XCTAssertTrue(config.isPresetLocked)
    }

    func testCustomPresetIsNotLocked() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertFalse(config.isPresetLocked)
    }

    func testActiveServiceNameOpenClaw() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "")
        XCTAssertEqual(config.activeServiceName.zh, "OpenClaw")
        XCTAssertEqual(config.activeServiceName.en, "OpenClaw")
    }

    func testActiveServiceNameHermes() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        XCTAssertEqual(config.activeServiceName.zh, "Hermes")
        XCTAssertEqual(config.activeServiceName.en, "Hermes")
    }

    func testActiveServiceNameCustom() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertEqual(config.activeServiceName.zh, "自定义")
        XCTAssertEqual(config.activeServiceName.en, "Custom")
    }

    func testSaveAndLoadRoundTrip() {
        var config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        config.save(to: defaults)

        let loaded = ServiceConfiguration.load(from: defaults)
        XCTAssertEqual(loaded.preset, .hermes)
        XCTAssertEqual(loaded.executable, "hermes")
        XCTAssertEqual(loaded.arguments, "gateway run")
        XCTAssertEqual(loaded.stopMode, .command)
        XCTAssertEqual(loaded.stopExecutable, "hermes")
        XCTAssertEqual(loaded.stopArguments, "gateway stop")
    }

    func testMigrateFromLegacyOpenClawConfig() {
        defaults.set("openclaw", forKey: "openclaw.executable")
        defaults.set("", forKey: "openclaw.arguments")
        defaults.set("command", forKey: "openclaw.stopMode")
        defaults.set("", forKey: "openclaw.stopExecutable")
        defaults.set("", forKey: "openclaw.stopArguments")

        let loaded = ServiceConfiguration.load(from: defaults)
        XCTAssertEqual(loaded.preset, .openclaw)
    }

    func testStopModeCommand() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        XCTAssertEqual(config.stopMode, .command)
    }

    func testStopModeKill() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertEqual(config.stopMode, .kill)
    }

    func testResolvedExecutableThrowsForMissingExecutable() {
        let config = ServiceConfiguration(preset: .custom, executable: "nonexistent_binary_xyz_12345", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertThrowsError(try config.resolvedExecutableURL()) { error in
            XCTAssertTrue(error is ServiceConfigurationError)
        }
    }

    func testResolvedStopExecutableReturnsNilWhenEmpty() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let result = try? config.resolvedStopExecutableURL()
        XCTAssertNil(result)
    }

    func testParsedArgumentsEmpty() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "")
        let args = try? config.parsedArguments()
        XCTAssertEqual(args?.count, 0)
    }

    func testParsedArgumentsWithSpaces() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "gateway run --port 8080", stopMode: .command, stopExecutable: "hermes", stopArguments: "")
        let args = try? config.parsedArguments()
        XCTAssertEqual(args, ["gateway", "run", "--port", "8080"])
    }

    func testParsedStopArgumentsForPresetReturnsEmpty() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        let args = try? config.parsedStopArguments()
        XCTAssertEqual(args?.count, 0)
    }
}