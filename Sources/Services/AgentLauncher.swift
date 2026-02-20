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

    static func buildGroupCommand(agent: Agent, taskItem: TaskItem) -> String {
        var lines = taskItem.issues.map { "#\($0.number): \($0.title)" }
        if let groupName = taskItem.groupName {
            lines.insert("Task Group: \(groupName)", at: 0)
        }
        let prompt = lines.joined(separator: "\n")
            .replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(agent.command) \"\(prompt)\""
    }

    /// 단일 이슈 실행
    func launch(paneId: String, agent: Agent, issue: Issue) async throws {
        let worktreePath = issue.worktreePath

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

        try await tmux.sendKeys(paneId, keys: "cd \(worktreePath)")
        try await Task.sleep(for: .milliseconds(500))
        let command = Self.buildCommand(agent: agent, issue: issue)
        try await tmux.sendKeys(paneId, keys: command)

        let title = "\(agent.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    /// TaskItem (그룹 포함) 실행
    func launchTaskItem(paneId: String, agent: Agent, taskItem: TaskItem) async throws {
        if taskItem.isSingle, let issue = taskItem.issues.first {
            try await launch(paneId: paneId, agent: agent, issue: issue)
            return
        }

        // 그룹: 첫 번째 이슈의 repo 기준으로 worktree 생성
        guard let firstIssue = taskItem.issues.first else { return }

        let worktreePath = firstIssue.worktreePath
        let exists = try await git.worktreeExists(
            repoPath: firstIssue.repo.localPath,
            targetPath: worktreePath
        )
        if !exists {
            try await git.addWorktree(
                repoPath: firstIssue.repo.localPath,
                branchName: firstIssue.branchName,
                targetPath: worktreePath
            )
        }

        try await tmux.sendKeys(paneId, keys: "cd \(worktreePath)")
        try await Task.sleep(for: .milliseconds(500))
        let command = Self.buildGroupCommand(agent: agent, taskItem: taskItem)
        try await tmux.sendKeys(paneId, keys: command)

        let title = "\(agent.displayName) | \(taskItem.displayName) (\(taskItem.issues.count) issues)"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    func stop(paneId: String) async throws {
        try await tmux.sendCtrlC(paneId)
    }
}
