// Sources/Services/AgentLauncher.swift
import Foundation

struct AgentLauncher {
    private let tmux: TmuxService
    private let git: GitService

    init(tmux: TmuxService, git: GitService) {
        self.tmux = tmux
        self.git = git
    }

    static func buildCommand(agent: Agent, issue: Issue) -> String {
        let prompt = "Fix #\(issue.number): \(issue.title)\n\n\(issue.body)"
            .replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(agent.command) \"\(prompt)\""
    }

    /// 이슈를 페인에 배치하고 Agent 실행
    func launch(paneId: String, agent: Agent, issue: Issue) async throws {
        let worktreePath = issue.worktreePath

        // 1. worktree가 없으면 생성
        let exists = try await git.worktreeExists(
            repoPath: issue.repo.localPath,
            targetPath: worktreePath
        )
        if !exists {
            try await git.addWorktree(
                repoPath: issue.repo.localPath,
                branchName: issue.branchName,
                targetPath: worktreePath
            )
        }

        // 2. 디렉토리 이동
        try await tmux.sendKeys(paneId, keys: "cd \(worktreePath)")

        // 3. 잠시 대기 후 Agent 실행
        try await Task.sleep(for: .milliseconds(500))
        let command = Self.buildCommand(agent: agent, issue: issue)
        try await tmux.sendKeys(paneId, keys: command)

        // 4. 페인 타이틀 설정
        let title = "\(agent.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    /// Agent 중단
    func stop(paneId: String) async throws {
        try await tmux.sendCtrlC(paneId)
    }
}
