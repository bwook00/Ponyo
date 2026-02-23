// Sources/Models/TaskItem.swift
import Foundation

struct TaskItem: Codable, Identifiable, Hashable {
    let id: String
    var issues: [Issue]
    var groupName: String?
    var manualTask: ManualTask?

    init(issue: Issue) {
        self.id = UUID().uuidString
        self.issues = [issue]
        self.groupName = nil
        self.manualTask = nil
    }

    init(issues: [Issue], groupName: String) {
        self.id = UUID().uuidString
        self.issues = issues
        self.groupName = groupName
        self.manualTask = nil
    }

    init(manualTask: ManualTask) {
        self.id = UUID().uuidString
        self.issues = []
        self.groupName = nil
        self.manualTask = manualTask
    }

    var isSingle: Bool { issues.count == 1 }
    var isGroup: Bool { issues.count > 1 }
    var isManual: Bool { manualTask != nil }

    var displayName: String {
        if let manualTask { return manualTask.title }
        if let groupName, !groupName.isEmpty { return groupName }
        if let first = issues.first { return first.displayTitle }
        return "Empty"
    }

    /// 드래그용 repo (첫 번째 이슈 기준)
    var primaryRepo: RepoConfig? { issues.first?.repo }

    // Backward compat — 기존 state.json에 manualTask 없어도 정상 로드
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        issues = try c.decodeIfPresent([Issue].self, forKey: .issues) ?? []
        groupName = try c.decodeIfPresent(String.self, forKey: .groupName)
        manualTask = try c.decodeIfPresent(ManualTask.self, forKey: .manualTask)
    }
}
