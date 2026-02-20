// Sources/Services/GitService.swift
import Foundation

actor GitService {
    private let shell: ShellRunner

    init(shell: ShellRunner) {
        self.shell = shell
    }

    func addWorktree(repoPath: String, branchName: String, targetPath: String) async throws {
        _ = try await shell.runCommand(
            "git", arguments: ["worktree", "add", targetPath, "-b", branchName],
            workingDirectory: repoPath
        )
    }

    func removeWorktree(repoPath: String, worktreePath: String) async throws {
        _ = try await shell.runCommand(
            "git", arguments: ["worktree", "remove", worktreePath, "--force"],
            workingDirectory: repoPath
        )
    }

    func listWorktrees(repoPath: String) async throws -> [String] {
        let output = try await shell.runCommand(
            "git", arguments: ["worktree", "list", "--porcelain"],
            workingDirectory: repoPath
        )
        return output
            .split(separator: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .map { String($0.dropFirst("worktree ".count)) }
    }

    func worktreeExists(repoPath: String, targetPath: String) async throws -> Bool {
        let worktrees = try await listWorktrees(repoPath: repoPath)
        let resolvedTarget = (targetPath as NSString).resolvingSymlinksInPath
        return worktrees.contains { path in
            (path as NSString).resolvingSymlinksInPath == resolvedTarget
        }
    }
}
