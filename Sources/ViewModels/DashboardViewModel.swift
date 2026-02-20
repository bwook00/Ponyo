// Sources/ViewModels/DashboardViewModel.swift
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: AppState
    @Published var isLoading = false

    let tmux: TmuxService
    let git: GitService
    let github: GitHubService
    let launcher: AgentLauncher
    let stateStore: StateStore
    let monitor: PaneMonitor

    init(
        tmux: TmuxService,
        git: GitService,
        github: GitHubService,
        stateStore: StateStore,
        monitor: PaneMonitor
    ) {
        self.tmux = tmux
        self.git = git
        self.github = github
        self.launcher = AgentLauncher(tmux: tmux, git: git)
        self.stateStore = stateStore
        self.monitor = monitor
        self.state = AppState(repos: [], taskPool: [], paneSlots: [])
    }

    // MARK: - Lifecycle

    func onAppear() async {
        // 1. 상태 복원
        if let loaded = try? await stateStore.load() {
            state = loaded
        }

        // 2. tmux 세션 확인/생성
        let exists = (try? await tmux.sessionExists()) ?? false
        if !exists {
            try? await tmux.createSession()
        }

        // 3. 모니터 시작
        monitor.start()
    }

    // MARK: - Task Pool

    func fetchIssues() async {
        isLoading = true
        defer { isLoading = false }

        var allIssues: [Issue] = []
        for repo in state.repos {
            if let issues = try? await github.fetchIssues(repo: repo) {
                allIssues.append(contentsOf: issues)
            }
        }
        state.taskPool = allIssues
        try? await stateStore.save(state)
    }

    // MARK: - Pane Management

    func addPane() async {
        do {
            let paneId = try await tmux.createPane()
            let slot = PaneSlot(paneId: paneId, agent: .claudeCode)
            state.paneSlots.append(slot)
            try? await stateStore.save(state)
        } catch {}
    }

    /// 이슈를 페인에 배치 (드래그 앤 드롭 완료 시)
    func assignIssue(_ issue: Issue, toPaneAt index: Int, agent: Agent) async {
        guard index < state.paneSlots.count else { return }

        // TaskPool에서 제거
        state.taskPool.removeAll { $0.id == issue.id }

        // PaneSlot에 배치
        state.paneSlots[index].issue = issue
        state.paneSlots[index].agent = agent
        state.paneSlots[index].status = .running

        // Agent 실행
        let paneId = state.paneSlots[index].paneId
        try? await launcher.launch(paneId: paneId, agent: agent, issue: issue)

        // GitHub 라벨 추가
        try? await github.addLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        try? await stateStore.save(state)
    }

    /// 되돌리기: 이슈를 TaskPool로
    func returnToPool(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let issue = state.paneSlots[paneIndex].issue else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // TaskPool로 되돌림
        state.taskPool.append(issue)
        state.paneSlots[paneIndex].issue = nil
        state.paneSlots[paneIndex].status = .idle

        // GitHub 라벨 제거
        try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        try? await stateStore.save(state)
    }

    /// 완료: worktree 삭제, 페인 삭제
    func completeTask(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let issue = state.paneSlots[paneIndex].issue else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // worktree 삭제 (브랜치는 유지)
        try? await git.removeWorktree(repoPath: issue.repo.localPath, worktreePath: issue.worktreePath)

        // 페인 삭제
        try? await tmux.killPane(paneId)

        // GitHub 라벨 제거
        try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        // 슬롯 제거
        state.paneSlots.remove(at: paneIndex)
        try? await stateStore.save(state)
    }

    // MARK: - Status Sync

    func syncPaneStatuses() {
        for i in state.paneSlots.indices {
            let paneId = state.paneSlots[i].paneId
            state.paneSlots[i].status = monitor.agentStatus(for: paneId)
        }
    }
}
