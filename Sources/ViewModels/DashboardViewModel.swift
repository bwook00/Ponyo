// Sources/ViewModels/DashboardViewModel.swift
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: AppState
    @Published var isLoading = false
    @Published var availableRepos: [GitHubRepoInfo] = []
    @Published var isLoadingRepos = false
    @Published var terminalLaunched = false

    let tmux: TmuxService
    let git: GitService
    private(set) var github: GitHubService
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
        self.state = AppState(repos: [], taskPool: [], todayTasks: [], paneSlots: [])
    }

    // MARK: - Lifecycle

    func initialize() async {
        if let loaded = try? await stateStore.load() {
            state = loaded
        }

        let exists = (try? await tmux.sessionExists()) ?? false
        if !exists {
            try? await tmux.createSession()
        }

        monitor.start()

        let hasToken = KeychainHelper.load(key: "github-token") != nil
        if hasToken {
            await ensureGitHubUsername()
            if !state.repos.isEmpty {
                await fetchIssues()
            }
        }
    }

    func refreshGitHubToken() {
        let token = KeychainHelper.load(key: "github-token") ?? ""
        github = GitHubService(token: token)
    }

    /// GitHub username 캐시 (auto-assign용)
    func ensureGitHubUsername() async {
        guard state.githubUsername.isEmpty else { return }
        if let username = try? await github.fetchCurrentUser() {
            state.githubUsername = username
            try? await stateStore.save(state)
        }
    }

    // MARK: - Terminal

    /// Ghostty(또는 설정된 터미널)를 tmux 세션에 attach하여 실행
    func launchTerminal() async {
        // tmux 세션 확인/생성
        let exists = (try? await tmux.sessionExists()) ?? false
        if !exists {
            try? await tmux.createSession()
        }

        let shell = ShellRunner()
        let app = state.terminalApp
        let session = state.tmuxSession

        // 터미널 앱 실행 + tmux attach
        switch app {
        case "Ghostty":
            // Ghostty: open -a 로 실행 후, tmux attach 명령을 보냄
            _ = try? await shell.runCommand(
                "open", arguments: ["-a", "Ghostty", "--args", "-e", "tmux new-session -A -s \(session)"]
            )
        case "iTerm":
            _ = try? await shell.runCommand(
                "open", arguments: ["-a", "iTerm"]
            )
            try? await Task.sleep(for: .seconds(1))
            // iTerm에서 tmux attach
            _ = try? await shell.runCommand(
                "osascript", arguments: [
                    "-e", "tell application \"iTerm\" to tell current session of current window to write text \"tmux new-session -A -s \(session)\""
                ]
            )
        default: // Terminal.app
            _ = try? await shell.runCommand(
                "open", arguments: ["-a", "Terminal"]
            )
            try? await Task.sleep(for: .seconds(1))
            _ = try? await shell.runCommand(
                "osascript", arguments: [
                    "-e", "tell application \"Terminal\" to do script \"tmux new-session -A -s \(session)\" in front window"
                ]
            )
        }

        terminalLaunched = true
    }

    // MARK: - Repo Management

    func fetchAvailableRepos() async {
        isLoadingRepos = true
        defer { isLoadingRepos = false }
        if let repos = try? await github.fetchUserRepos() {
            availableRepos = repos
        }
    }

    func addRepo(_ info: GitHubRepoInfo, localPath: String) async {
        let repo = RepoConfig(owner: info.owner, name: info.name, localPath: localPath)
        guard !state.repos.contains(where: { $0.id == repo.id }) else { return }
        state.repos.append(repo)
        try? await stateStore.save(state)
        await fetchIssuesForRepo(repo)
    }

    func removeRepo(_ repo: RepoConfig) async {
        state.repos.removeAll { $0.id == repo.id }
        state.taskPool.removeAll { $0.repo.id == repo.id }
        // todayTasks에서도 해당 레포 이슈 제거
        state.todayTasks.removeAll { item in
            item.issues.allSatisfy { $0.repo.id == repo.id }
        }
        // 그룹 안의 부분 이슈도 정리
        for i in state.todayTasks.indices {
            state.todayTasks[i].issues.removeAll { $0.repo.id == repo.id }
        }
        state.todayTasks.removeAll { $0.issues.isEmpty }
        try? await stateStore.save(state)
    }

    func findLocalClone(for info: GitHubRepoInfo) async -> String? {
        let shell = ShellRunner()
        guard let output = try? await shell.runCommand(
            "mdfind",
            arguments: ["kMDItemFSName == '\(info.name)' && kMDItemContentType == 'public.folder'"]
        ) else { return nil }

        let candidates = output.split(separator: "\n").map(String.init)
        let expectedSuffix = "\(info.owner)/\(info.name)"
        for path in candidates {
            let gitConfig = "\(path)/.git/config"
            guard FileManager.default.fileExists(atPath: gitConfig),
                  let content = try? String(contentsOfFile: gitConfig, encoding: .utf8) else { continue }
            if content.contains(expectedSuffix) {
                return path
            }
        }
        return nil
    }

    // MARK: - Task Pool (GitHub Issues)

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

    func fetchIssuesForRepo(_ repo: RepoConfig) async {
        isLoading = true
        defer { isLoading = false }

        state.taskPool.removeAll { $0.repo.id == repo.id }
        if let issues = try? await github.fetchIssues(repo: repo) {
            state.taskPool.append(contentsOf: issues)
        }
        try? await stateStore.save(state)
    }

    func issuesForRepo(_ repo: RepoConfig) -> [Issue] {
        // taskPool에서 아직 todayTasks나 pane에 안 들어간 것만 표시
        let pickedIds = Set(
            state.todayTasks.flatMap { $0.issues.map(\.id) }
            + state.paneSlots.compactMap { $0.taskItem }.flatMap { $0.issues.map(\.id) }
        )
        return state.taskPool
            .filter { $0.repo.id == repo.id && !pickedIds.contains($0.id) }
    }

    // MARK: - Today's Tasks (Step 1: Pick)

    /// 이슈를 오늘의 할일로 추가 + GitHub에서 나를 assign
    func pickForToday(_ issue: Issue) {
        let alreadyPicked = state.todayTasks.flatMap(\.issues).contains(where: { $0.id == issue.id })
        guard !alreadyPicked else { return }
        let item = TaskItem(issue: issue)
        state.todayTasks.append(item)
        Task {
            try? await stateStore.save(state)
            // GitHub에서 나를 assign
            if !state.githubUsername.isEmpty {
                try? await github.assignIssue(
                    repo: issue.repo,
                    issueNumber: issue.number,
                    assignee: state.githubUsername
                )
            }
        }
    }

    /// 오늘의 할일에서 제거 (taskPool로 돌아감)
    func removeFromToday(_ taskItem: TaskItem) {
        state.todayTasks.removeAll { $0.id == taskItem.id }
        Task { try? await stateStore.save(state) }
    }

    /// 여러 TaskItem을 그룹으로 묶기
    func groupTasks(_ itemIds: Set<String>, name: String) {
        let items = state.todayTasks.filter { itemIds.contains($0.id) }
        let allIssues = items.flatMap(\.issues)
        guard allIssues.count >= 2 else { return }

        // 기존 항목 제거
        state.todayTasks.removeAll { itemIds.contains($0.id) }
        // 새 그룹 생성
        let group = TaskItem(issues: allIssues, groupName: name)
        state.todayTasks.append(group)
        Task { try? await stateStore.save(state) }
    }

    /// 그룹 해제 → 개별 TaskItem으로 분리
    func ungroupTask(_ taskItem: TaskItem) {
        guard taskItem.isGroup else { return }
        state.todayTasks.removeAll { $0.id == taskItem.id }
        for issue in taskItem.issues {
            state.todayTasks.append(TaskItem(issue: issue))
        }
        Task { try? await stateStore.save(state) }
    }

    // MARK: - Pane Management (Step 2: Assign)

    func addPane() async {
        // 첫 pane 생성 시 터미널 자동 실행
        if !terminalLaunched {
            await launchTerminal()
            try? await Task.sleep(for: .seconds(2))
        }

        do {
            let paneId = try await tmux.createPane()
            let slot = PaneSlot(paneId: paneId, agent: .claudeCode)
            state.paneSlots.append(slot)
            try? await stateStore.save(state)
        } catch {}
    }

    /// TaskItem을 Pane에 할당
    func assignTask(_ taskItem: TaskItem, toPaneAt index: Int, agent: Agent) async {
        guard index < state.paneSlots.count else { return }

        // todayTasks에서 제거
        state.todayTasks.removeAll { $0.id == taskItem.id }

        // PaneSlot에 배치
        state.paneSlots[index].taskItem = taskItem
        state.paneSlots[index].agent = agent
        state.paneSlots[index].status = .running

        // Agent 실행
        let paneId = state.paneSlots[index].paneId
        try? await launcher.launchTaskItem(paneId: paneId, agent: agent, taskItem: taskItem)

        // GitHub 라벨 추가
        for issue in taskItem.issues {
            try? await github.addLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")
        }

        try? await stateStore.save(state)
    }

    /// Pane에서 todayTasks로 되돌리기
    func returnToToday(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let taskItem = state.paneSlots[paneIndex].taskItem else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // todayTasks로 돌림
        state.todayTasks.append(taskItem)
        state.paneSlots[paneIndex].taskItem = nil
        state.paneSlots[paneIndex].status = .idle

        for issue in taskItem.issues {
            try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")
        }

        try? await stateStore.save(state)
    }

    /// 완료: worktree 삭제, 페인 삭제
    func completeTask(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let taskItem = state.paneSlots[paneIndex].taskItem else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // 각 이슈의 worktree 삭제
        for issue in taskItem.issues {
            try? await git.removeWorktree(repoPath: issue.repo.localPath, worktreePath: issue.worktreePath)
            try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")
        }

        try? await tmux.killPane(paneId)
        state.paneSlots.remove(at: paneIndex)
        try? await stateStore.save(state)
    }

    // MARK: - Agent Restart

    func restartAgent(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let taskItem = state.paneSlots[paneIndex].taskItem else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        let agent = state.paneSlots[paneIndex].agent

        try? await launcher.stop(paneId: paneId)
        try? await launcher.launchTaskItem(paneId: paneId, agent: agent, taskItem: taskItem)
        state.paneSlots[paneIndex].status = .running
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
