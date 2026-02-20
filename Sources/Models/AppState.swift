// Sources/Models/AppState.swift
import Foundation

struct AppState: Codable {
    var repos: [RepoConfig]
    var taskPool: [Issue]
    var todayTasks: [TaskItem]
    var paneSlots: [PaneSlot]
    var tmuxSession: String
    var terminalApp: String
    var githubUsername: String

    init(
        repos: [RepoConfig] = [],
        taskPool: [Issue] = [],
        todayTasks: [TaskItem] = [],
        paneSlots: [PaneSlot] = [],
        tmuxSession: String = "ponyo",
        terminalApp: String = "Ghostty",
        githubUsername: String = ""
    ) {
        self.repos = repos
        self.taskPool = taskPool
        self.todayTasks = todayTasks
        self.paneSlots = paneSlots
        self.tmuxSession = tmuxSession
        self.terminalApp = terminalApp
        self.githubUsername = githubUsername
    }

    // 새 필드가 추가되어도 기존 JSON을 정상 로드하도록 커스텀 디코더
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        repos = try c.decodeIfPresent([RepoConfig].self, forKey: .repos) ?? []
        taskPool = try c.decodeIfPresent([Issue].self, forKey: .taskPool) ?? []
        todayTasks = try c.decodeIfPresent([TaskItem].self, forKey: .todayTasks) ?? []
        paneSlots = try c.decodeIfPresent([PaneSlot].self, forKey: .paneSlots) ?? []
        tmuxSession = try c.decodeIfPresent(String.self, forKey: .tmuxSession) ?? "ponyo"
        terminalApp = try c.decodeIfPresent(String.self, forKey: .terminalApp) ?? "Ghostty"
        githubUsername = try c.decodeIfPresent(String.self, forKey: .githubUsername) ?? ""
    }
}
