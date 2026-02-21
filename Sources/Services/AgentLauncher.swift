// Sources/Services/AgentLauncher.swift
import Foundation

struct AgentLauncher {
    private let tmux: TmuxService
    private let git: GitService

    init(tmux: TmuxService, git: GitService) {
        self.tmux = tmux
        self.git = git
    }

    /// 단일 이슈 — 레포로 cd + agent만 실행 (prompt 안 보냄)
    func launch(paneId: String, paneIndex: Int, agent: Agent, issue: Issue) async throws {
        let repoPath = issue.repo.localPath

        try? await git.createBranch(repoPath: repoPath, branchName: issue.branchName)

        try await tmux.sendKeys(paneId, keys: "cd \(repoPath)")
        try await Task.sleep(for: .milliseconds(500))
        try await tmux.sendKeys(paneId, keys: "git checkout \(issue.branchName)")
        try await Task.sleep(for: .milliseconds(500))
        try await tmux.sendKeys(paneId, keys: "clear")
        try await Task.sleep(for: .milliseconds(300))
        try await tmux.sendKeys(paneId, keys: agent.command)

        // "Ponyo 1: Ponyo-#10 Add Notification for agent completion"
        let title = "🐟 Ponyo \(paneIndex + 1): \(issue.repo.name)-#\(issue.number) \(issue.title)"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    /// TaskItem (그룹 포함) — 레포로 cd + agent만 실행
    func launchTaskItem(paneId: String, paneIndex: Int, agent: Agent, taskItem: TaskItem) async throws {
        if taskItem.isSingle, let issue = taskItem.issues.first {
            try await launch(paneId: paneId, paneIndex: paneIndex, agent: agent, issue: issue)
            return
        }

        guard let firstIssue = taskItem.issues.first else { return }
        let repoPath = firstIssue.repo.localPath

        try await tmux.sendKeys(paneId, keys: "cd \(repoPath)")
        try await Task.sleep(for: .milliseconds(500))
        try await tmux.sendKeys(paneId, keys: "clear")
        try await Task.sleep(for: .milliseconds(300))
        try await tmux.sendKeys(paneId, keys: agent.command)

        let issueList = taskItem.issues.map { "\($0.repo.name)-#\($0.number)" }.joined(separator: ", ")
        let title = "🐟 Ponyo \(paneIndex + 1): \(taskItem.displayName) [\(issueList)]"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    /// 빈 pane에 기본 타이틀 설정
    func setIdleTitle(paneId: String, paneIndex: Int) async throws {
        try await tmux.setPaneTitle(paneId, title: "🐟 Ponyo \(paneIndex + 1): idle")
    }

    func stop(paneId: String) async throws {
        try await tmux.sendCtrlC(paneId)
    }
}
