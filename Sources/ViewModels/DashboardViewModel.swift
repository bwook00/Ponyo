// Sources/ViewModels/DashboardViewModel.swift
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: AppState
    @Published var isLoading = false
    @Published var availableRepos: [GitHubRepoInfo] = []
    @Published var isLoadingRepos = false
    @Published var terminalLaunched = false
    @Published var isInitialized = false

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

        isInitialized = true

        guard !state.githubToken.isEmpty else { return }

        github = GitHubService(token: state.githubToken)

        monitor.start()

        await ensureGitHubUsername()
        if !state.repos.isEmpty {
            await fetchIssues()
        }
    }

    func refreshGitHubToken() {
        github = GitHubService(token: state.githubToken)
        Task { try? await stateStore.save(state) }
    }

    func ensureGitHubUsername() async {
        guard state.githubUsername.isEmpty else { return }
        if let username = try? await github.fetchCurrentUser() {
            state.githubUsername = username
            try? await stateStore.save(state)
        }
    }

    // MARK: - Terminal

    /// Ghostty + tmux 세션을 새로 만들고 pane 세팅 (기존 task 할당 유지)
    func launchTerminal() async {
        // 1. 기존 세션 죽이고 새로 생성
        let exists = (try? await tmux.sessionExists()) ?? false
        if exists {
            try? await tmux.killSession()
        }
        try? await tmux.createSession()

        // 2. 기존 task 할당 보존
        let savedSlots = state.paneSlots
        let paneCount = max(savedSlots.count, 4)
        state.paneSlots.removeAll()

        // 세션 생성 시 자동 생성된 첫 pane
        if let panes = try? await tmux.listPanes(), let first = panes.first {
            var slot = PaneSlot(paneId: first.id, agent: .claudeCode)
            if savedSlots.indices.contains(0) {
                slot.taskItem = savedSlots[0].taskItem
                slot.agent = savedSlots[0].agent
                slot.status = savedSlots[0].taskItem != nil ? .running : .idle
            }
            state.paneSlots.append(slot)
        }

        // 나머지 pane 추가
        for i in 1..<paneCount {
            if let paneId = try? await tmux.createPane() {
                var slot = PaneSlot(paneId: paneId, agent: .claudeCode)
                if savedSlots.indices.contains(i) {
                    slot.taskItem = savedSlots[i].taskItem
                    slot.agent = savedSlots[i].agent
                    slot.status = savedSlots[i].taskItem != nil ? .running : .idle
                }
                state.paneSlots.append(slot)
            } else {
                break
            }
        }
        try? await stateStore.save(state)

        // 3. Ghostty 실행
        let shell = ShellRunner()
        let session = state.tmuxSession
        try? await shell.launch(
            "/Applications/Ghostty.app/Contents/MacOS/ghostty",
            arguments: ["-e", "/bin/sh", "-c", "tmux attach -t \(session)"]
        )

        terminalLaunched = true

        // 4. 각 pane에 타이틀 설정 + task 할당된 pane에 agent 재실행
        try? await Task.sleep(for: .seconds(1))
        for i in state.paneSlots.indices {
            if let taskItem = state.paneSlots[i].taskItem {
                let paneId = state.paneSlots[i].paneId
                let agent = state.paneSlots[i].agent
                try? await launcher.launchTaskItem(paneId: paneId, paneIndex: i, agent: agent, taskItem: taskItem)
            } else {
                try? await launcher.setIdleTitle(paneId: state.paneSlots[i].paneId, paneIndex: i)
            }
        }
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
        state.todayTasks.removeAll { item in
            item.issues.allSatisfy { $0.repo.id == repo.id }
        }
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
        let pickedIds = Set(
            state.todayTasks.flatMap { $0.issues.map(\.id) }
            + state.paneSlots.compactMap { $0.taskItem }.flatMap { $0.issues.map(\.id) }
        )
        return state.taskPool
            .filter { $0.repo.id == repo.id && !pickedIds.contains($0.id) }
    }

    // MARK: - Today's Tasks (Step 1: Pick)

    func pickForToday(_ issue: Issue) {
        let alreadyPicked = state.todayTasks.flatMap(\.issues).contains(where: { $0.id == issue.id })
        guard !alreadyPicked else { return }
        let item = TaskItem(issue: issue)
        state.todayTasks.append(item)
        Task {
            try? await stateStore.save(state)
            if !state.githubUsername.isEmpty {
                try? await github.assignIssue(
                    repo: issue.repo,
                    issueNumber: issue.number,
                    assignee: state.githubUsername
                )
            }
        }
    }

    func removeFromToday(_ taskItem: TaskItem) {
        state.todayTasks.removeAll { $0.id == taskItem.id }
        Task { try? await stateStore.save(state) }
    }

    func groupTasks(_ itemIds: Set<String>, name: String) {
        let items = state.todayTasks.filter { itemIds.contains($0.id) }
        let allIssues = items.flatMap(\.issues)
        guard allIssues.count >= 2 else { return }
        state.todayTasks.removeAll { itemIds.contains($0.id) }
        let group = TaskItem(issues: allIssues, groupName: name)
        state.todayTasks.append(group)
        Task { try? await stateStore.save(state) }
    }

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
        if terminalLaunched {
            if let paneId = try? await tmux.createPane() {
                state.paneSlots.append(PaneSlot(paneId: paneId, agent: .claudeCode))
                try? await stateStore.save(state)
            }
        } else {
            state.paneSlots.append(PaneSlot(paneId: "pending-\(UUID().uuidString.prefix(8))", agent: .claudeCode))
            try? await stateStore.save(state)
        }
    }

    /// Pane 삭제
    func removePane(at index: Int) async {
        guard index < state.paneSlots.count else { return }
        let slot = state.paneSlots[index]

        // task 있으면 todayTasks로 돌림
        if let taskItem = slot.taskItem {
            try? await launcher.stop(paneId: slot.paneId)
            state.todayTasks.append(taskItem)
        }

        // tmux pane 삭제
        if terminalLaunched {
            try? await tmux.killPane(slot.paneId)
        }

        state.paneSlots.remove(at: index)
        try? await stateStore.save(state)
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

        // 터미널 열려있으면 바로 실행
        if terminalLaunched {
            let paneId = state.paneSlots[index].paneId
            try? await launcher.launchTaskItem(paneId: paneId, paneIndex: index, agent: agent, taskItem: taskItem)
        }

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

        state.todayTasks.append(taskItem)
        state.paneSlots[paneIndex].taskItem = nil
        state.paneSlots[paneIndex].status = .idle

        for issue in taskItem.issues {
            try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")
        }

        try? await stateStore.save(state)
    }

    /// 완료
    func completeTask(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let taskItem = state.paneSlots[paneIndex].taskItem else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        for issue in taskItem.issues {
            try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")
        }

        if terminalLaunched {
            try? await tmux.killPane(paneId)
        }
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
        try? await launcher.launchTaskItem(paneId: paneId, paneIndex: paneIndex, agent: agent, taskItem: taskItem)
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
