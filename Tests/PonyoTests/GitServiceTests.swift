// Tests/PonyoTests/GitServiceTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct GitServiceTests {
    let service = GitService(shell: ShellRunner())

    @Test func worktreeLifecycle() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-git-test-\(UUID().uuidString)")
        let repoPath = tmpDir.appendingPathComponent("repo").path
        let worktreePath = tmpDir.appendingPathComponent("wt").path

        // setup: git init + initial commit
        let shell = ShellRunner()
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        _ = try await shell.runCommand("git", arguments: ["init"], workingDirectory: repoPath)
        _ = try await shell.runCommand("git", arguments: [
            "commit", "--allow-empty", "-m", "init"
        ], workingDirectory: repoPath)

        defer { try? FileManager.default.removeItem(atPath: tmpDir.path) }

        // worktree 추가
        try await service.addWorktree(repoPath: repoPath, branchName: "feat/test", targetPath: worktreePath)
        #expect(FileManager.default.fileExists(atPath: worktreePath))

        // worktree 존재 확인
        let exists = try await service.worktreeExists(repoPath: repoPath, targetPath: worktreePath)
        #expect(exists == true)

        // worktree 목록 확인
        let worktrees = try await service.listWorktrees(repoPath: repoPath)
        #expect(worktrees.count == 2) // main + new worktree

        // worktree 삭제
        try await service.removeWorktree(repoPath: repoPath, worktreePath: worktreePath)
        #expect(!FileManager.default.fileExists(atPath: worktreePath))

        // 삭제 후 존재하지 않음 확인
        let existsAfter = try await service.worktreeExists(repoPath: repoPath, targetPath: worktreePath)
        #expect(existsAfter == false)
    }
}
