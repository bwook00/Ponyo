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

    init(shell: ShellRunner, session: String = "ponyo") {
        self.shell = shell
        self.session = session
    }

    func sessionExists() async throws -> Bool {
        do {
            _ = try await shell.runCommand("tmux", arguments: ["has-session", "-t", session])
            return true
        } catch {
            return false
        }
    }

    func createSession() async throws {
        _ = try await shell.runCommand("tmux", arguments: ["new-session", "-d", "-s", session])
    }

    func killSession() async throws {
        _ = try await shell.runCommand("tmux", arguments: ["kill-session", "-t", session])
    }

    func listPanes() async throws -> [TmuxPaneInfo] {
        let format = "#{pane_id}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}"
        let output = try await shell.runCommand(
            "tmux", arguments: ["list-panes", "-t", session, "-F", format]
        )
        return output
            .split(separator: "\n")
            .compactMap { line -> TmuxPaneInfo? in
                let parts = line.split(separator: "\t", maxSplits: 4).map(String.init)
                guard parts.count == 5, let index = Int(parts[1]), let pid = Int(parts[2]) else { return nil }
                return TmuxPaneInfo(id: parts[0], index: index, pid: pid, command: parts[3], title: parts[4])
            }
    }

    func createPane() async throws -> String {
        let output = try await shell.runCommand(
            "tmux", arguments: ["split-window", "-t", session, "-P", "-F", "#{pane_id}"]
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func killPane(_ paneId: String) async throws {
        _ = try await shell.runCommand("tmux", arguments: ["kill-pane", "-t", paneId])
    }

    func sendKeys(_ paneId: String, keys: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["send-keys", "-t", paneId, keys, "Enter"]
        )
    }

    func setPaneTitle(_ paneId: String, title: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["select-pane", "-t", paneId, "-T", title]
        )
    }

    func sendCtrlC(_ paneId: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["send-keys", "-t", paneId, "C-c"]
        )
    }
}
