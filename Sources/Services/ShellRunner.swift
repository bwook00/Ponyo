// Sources/Services/ShellRunner.swift
import Foundation

struct ShellError: Error {
    let exitCode: Int32
    let stderr: String
}

actor ShellRunner {
    /// AI agent 환경변수를 제거하고 Homebrew PATH를 보장하는 클린 환경
    /// (macOS GUI 앱은 Finder에서 실행 시 PATH가 /usr/bin:/bin 등 최소값만 가짐)
    private static let cleanEnv: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "CLAUDECODE")
        env.removeValue(forKey: "CLAUDE_CODE")
        if let path = env["PATH"] {
            var newPath = path
            for dir in ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"] {
                if !newPath.contains(dir) {
                    newPath = "\(dir):\(newPath)"
                }
            }
            env["PATH"] = newPath
        }
        return env
    }()

    func run(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.environment = Self.cleanEnv
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

    /// Fire-and-forget: 프로세스를 실행하고 기다리지 않음 (GUI 앱 실행용)
    func launch(_ executablePath: String, arguments: [String] = []) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = Self.cleanEnv
        try process.run()
    }
}
