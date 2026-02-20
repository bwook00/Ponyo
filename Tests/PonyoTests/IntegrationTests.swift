// Tests/PonyoTests/IntegrationTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct IntegrationTests {
    /// Full workflow: worktree creation -> tmux pane creation -> cleanup
    @Test func fullWorkflow() async throws {
        let shell = ShellRunner()
        let tmux = TmuxService(shell: shell, session: "ponyo-integration-test")
        let git = GitService(shell: shell)

        // Cleanup any leftover test session
        try? await tmux.killSession()

        // Setup: temporary git repo
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-integ-\(UUID().uuidString)")
        let repoPath = tmpDir.appendingPathComponent("repo").path
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        _ = try await shell.runCommand("git", arguments: ["init"], workingDirectory: repoPath)
        _ = try await shell.runCommand("git", arguments: [
            "commit", "--allow-empty", "-m", "init"
        ], workingDirectory: repoPath)

        let repo = RepoConfig(owner: "test", name: "repo", localPath: repoPath)
        let issue = Issue(number: 1, title: "Test issue", body: "body", labels: [], repo: repo)

        defer {
            // Cleanup
            Task {
                try? await tmux.killSession()
                try? FileManager.default.removeItem(atPath: tmpDir.path)
                try? FileManager.default.removeItem(atPath: issue.worktreePath)
            }
        }

        // 1. tmux session creation
        try await tmux.createSession()
        let exists = try await tmux.sessionExists()
        #expect(exists)

        // 2. Get initial pane
        let initialPanes = try await tmux.listPanes()
        #expect(initialPanes.count == 1)
        let paneId = initialPanes[0].id

        // 3. worktree creation
        try await git.addWorktree(
            repoPath: repoPath,
            branchName: issue.branchName,
            targetPath: issue.worktreePath
        )
        #expect(FileManager.default.fileExists(atPath: issue.worktreePath))

        // 4. Verify worktree exists check
        let worktreeExists = try await git.worktreeExists(
            repoPath: repoPath,
            targetPath: issue.worktreePath
        )
        #expect(worktreeExists)

        // 5. Set pane title
        let title = "\(Agent.claudeCode.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
        try await tmux.setPaneTitle(paneId, title: title)
        let updatedPanes = try await tmux.listPanes()
        #expect(updatedPanes[0].title == title)

        // 6. Build agent command
        let cmd = AgentLauncher.buildCommand(agent: .claudeCode, issue: issue)
        #expect(cmd.contains("claude"))
        #expect(cmd.contains("#1"))

        // 7. State persistence
        let stateDir = tmpDir.appendingPathComponent("state").path
        let store = StateStore(directory: stateDir)
        let state = AppState(
            repos: [repo],
            taskPool: [issue],
            paneSlots: [PaneSlot(paneId: paneId, agent: .claudeCode, issue: issue, status: .running)]
        )
        try await store.save(state)
        let loaded = try await store.load()
        #expect(loaded.taskPool.count == 1)
        #expect(loaded.paneSlots.count == 1)
        #expect(loaded.paneSlots[0].status == .running)

        // 8. Cleanup: worktree removal
        try await git.removeWorktree(repoPath: repoPath, worktreePath: issue.worktreePath)
        #expect(!FileManager.default.fileExists(atPath: issue.worktreePath))

        // 9. Session cleanup
        try await tmux.killSession()
        let existsAfter = try await tmux.sessionExists()
        #expect(!existsAfter)
    }
}
