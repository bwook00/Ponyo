// Sources/Services/TmuxService.swift
import Foundation

struct TmuxPaneInfo {
    let id: String
    let index: Int
    let pid: Int
    let command: String
    let title: String
}

actor TmuxService {
    private let shell: ShellRunner
    let session: String
    private var resolvedPath: String?

    init(shell: ShellRunner, session: String = "ponyo") {
        self.shell = shell
        self.session = session
    }

    /// tmux 바이너리의 절대경로를 한 번 찾아서 캐싱
    func tmuxPath() async -> String {
        if let path = resolvedPath { return path }
        // Homebrew (Apple Silicon), Homebrew (Intel), system
        let candidates = [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                resolvedPath = path
                return path
            }
        }
        // 최후의 수단: env를 통해 시도
        resolvedPath = "tmux"
        return "tmux"
    }

    private static let logFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".ponyo/tmux-debug.log")

    private func log(_ msg: String) {
        let line = "\(Date()): \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: Self.logFile.path) {
                if let handle = try? FileHandle(forWritingTo: Self.logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? FileManager.default.createDirectory(
                    at: Self.logFile.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try? data.write(to: Self.logFile)
            }
        }
    }

    private func runTmux(_ arguments: [String]) async throws -> String {
        let path = await tmuxPath()
        log("RUN: \(path) \(arguments.joined(separator: " "))")
        do {
            let result: String
            if path == "tmux" {
                result = try await shell.runCommand("tmux", arguments: arguments)
            } else {
                result = try await shell.run(path, arguments: arguments)
            }
            log("OK: \(result.prefix(200))")
            return result
        } catch {
            log("ERR: \(error)")
            throw error
        }
    }

    func sessionExists() async throws -> Bool {
        do {
            _ = try await runTmux(["has-session", "-t", session])
            return true
        } catch {
            return false
        }
    }

    /// 세션 생성 후 첫 pane ID 반환
    func createSession() async throws -> String {
        let output = try await runTmux(["new-session", "-d", "-s", session, "-P", "-F", "#{pane_id}"])
        _ = try? await runTmux(["set-window-option", "-t", session, "pane-border-status", "top"])
        _ = try? await runTmux(["set-window-option", "-t", session, "pane-border-format", " #[bold,fg=colour75]#{@ponyo} "])
        _ = try? await runTmux(["set-option", "-t", session, "pane-border-lines", "heavy"])
        _ = try? await runTmux(["set-option", "-t", session, "pane-border-style", "fg=colour245"])
        _ = try? await runTmux(["set-option", "-t", session, "pane-active-border-style", "fg=colour39,bold"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func killSession() async throws {
        _ = try await runTmux(["kill-session", "-t", session])
    }

    func listPanes() async throws -> [TmuxPaneInfo] {
        let format = "#{pane_id}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}"
        let output = try await runTmux(["list-panes", "-t", session, "-F", format])
        return output
            .split(separator: "\n")
            .compactMap { line -> TmuxPaneInfo? in
                let parts = line.split(separator: "\t", maxSplits: 4).map(String.init)
                guard parts.count == 5, let index = Int(parts[1]), let pid = Int(parts[2]) else { return nil }
                return TmuxPaneInfo(id: parts[0], index: index, pid: pid, command: parts[3], title: parts[4])
            }
    }

    func createPane() async throws -> String {
        let output = try await runTmux(
            ["split-window", "-h", "-t", session, "-P", "-F", "#{pane_id}"]
        )
        // 생성 중에는 even-horizontal로 분할 가능 공간 확보
        _ = try? await runTmux(["select-layout", "-t", session, "even-horizontal"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ghostty 창이 열린 후 호출 — tiled 레이아웃으로 2×N 그리드 적용
    func applyLayout() async {
        _ = try? await runTmux(["select-layout", "-t", session, "tiled"])
    }

    func killPane(_ paneId: String) async throws {
        _ = try await runTmux(["kill-pane", "-t", paneId])
    }

    func sendKeys(_ paneId: String, keys: String) async throws {
        _ = try await runTmux(["send-keys", "-t", paneId, keys, "Enter"])
    }

    func setPaneTitle(_ paneId: String, title: String) async throws {
        _ = try await runTmux(["set-option", "-p", "-t", paneId, "@ponyo", title])
    }

    func swapPanes(_ paneId1: String, _ paneId2: String) async throws {
        _ = try await runTmux(["swap-pane", "-s", paneId1, "-t", paneId2])
    }

    func sendCtrlC(_ paneId: String) async throws {
        _ = try await runTmux(["send-keys", "-t", paneId, "C-c"])
    }
}
