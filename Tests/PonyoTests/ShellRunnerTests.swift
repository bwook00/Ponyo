// Tests/PonyoTests/ShellRunnerTests.swift
import Testing
import Foundation
@testable import Ponyo

@Test func shellRunnerEcho() async throws {
    let runner = ShellRunner()
    let output = try await runner.run("/bin/echo", arguments: ["hello"])
    #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

@Test func shellRunnerFailure() async {
    let runner = ShellRunner()
    do {
        _ = try await runner.run("/usr/bin/false")
        #expect(Bool(false), "Should have thrown")
    } catch let error as ShellError {
        #expect(error.exitCode != 0)
    } catch {
        #expect(Bool(false), "Wrong error type: \(error)")
    }
}

@Test func shellRunnerCommandViaEnv() async throws {
    let runner = ShellRunner()
    let output = try await runner.runCommand("echo", arguments: ["world"])
    #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "world")
}
