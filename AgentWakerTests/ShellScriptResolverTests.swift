import XCTest
@testable import AgentWaker

final class ShellScriptResolverTests: XCTestCase {

    func testOpenClawPresetHasStartScriptName() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        XCTAssertEqual(config.preset.startScriptName, "start_openclaw.sh")
    }

    func testOpenClawPresetHasStopScriptName() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        XCTAssertEqual(config.preset.stopScriptName, "stop_openclaw.sh")
    }

    func testHermesPresetHasStartScriptName() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        XCTAssertEqual(config.preset.startScriptName, "start_hermes.sh")
    }

    func testHermesPresetHasStopScriptName() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        XCTAssertEqual(config.preset.stopScriptName, "stop_hermes.sh")
    }

    func testCustomPresetHasNoScriptNames() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertTrue(config.preset.startScriptName.isEmpty)
        XCTAssertTrue(config.preset.stopScriptName.isEmpty)
    }

    func testBundledScriptURLReturnsNilForEmptyName() {
        let config = ServiceConfiguration(preset: .custom, executable: "myagent", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        XCTAssertNil(config.bundledScriptURL(named: ""))
    }

    func testCustomPresetResolvedExecutableBypassesBundledScript() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let url = try? config.resolvedExecutableURL()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.path, "/bin/ls")
    }

    func testParsedArgumentsReturnsEmptyForPresetStartScript() {
        let config = ServiceConfiguration(preset: .openclaw, executable: "openclaw", arguments: "", stopMode: .command, stopExecutable: "openclaw", stopArguments: "gateway stop")
        let args = try? config.parsedArguments()
        XCTAssertNotNil(args)
        XCTAssertEqual(args?.count, 0)
    }

    func testParsedArgumentsReturnsEmptyForHermesPresetStartScript() {
        let config = ServiceConfiguration(preset: .hermes, executable: "hermes", arguments: "gateway run", stopMode: .command, stopExecutable: "hermes", stopArguments: "gateway stop")
        let args = try? config.parsedArguments()
        XCTAssertNotNil(args)
        if config.bundledScriptURL(named: config.preset.startScriptName) != nil {
            XCTAssertEqual(args?.count, 0)
        } else {
            XCTAssertEqual(args?.count, 2)
            XCTAssertEqual(args, ["gateway", "run"])
        }
    }

    func testCustomPresetStillResolvesUserExecutable() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "-la /tmp", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let url = try? config.resolvedExecutableURL()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.path, "/bin/ls")
    }

    func testCustomPresetParsedArgumentsWorkNormally() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "-la", stopMode: .kill, stopExecutable: "", stopArguments: "")
        let args = try? config.parsedArguments()
        XCTAssertEqual(args, ["-la"])
    }

    func testCustomPresetParsedStopArgumentsWorkNormally() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "", stopMode: .command, stopExecutable: "/bin/kill", stopArguments: "-TERM 1234")
        let args = try? config.parsedStopArguments()
        XCTAssertEqual(args, ["-TERM", "1234"])
    }

    func testResolvedStopExecutableURLReturnsPathForCustom() {
        let config = ServiceConfiguration(preset: .custom, executable: "/bin/ls", arguments: "", stopMode: .command, stopExecutable: "/bin/kill", stopArguments: "")
        let url = try? config.resolvedStopExecutableURL()
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.path, "/bin/kill")
    }
}