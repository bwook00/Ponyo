// Sources/Services/ShellRunner.swift
import Foundation

struct ShellError: Error {
    let exitCode: Int32
    let stderr: String
}

actor ShellRunner {
    func run(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw ShellError(
                exitCode: process.terminationStatus,
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }

        return String(data: stdoutData, encoding: .utf8) ?? ""
    }

    /// command가 PATH에 있는 경우 /usr/bin/env를 통해 실행
    func runCommand(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) async throws -> String {
        try await run("/usr/bin/env", arguments: [command] + arguments, workingDirectory: workingDirectory)
    }
}
