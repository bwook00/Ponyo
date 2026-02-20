// Sources/Models/TaskItem.swift
import Foundation

struct TaskItem: Codable, Identifiable, Hashable {
    let id: String
    var issues: [Issue]
    var groupName: String?

    init(issue: Issue) {
        self.id = UUID().uuidString
        self.issues = [issue]
        self.groupName = nil
    }

    init(issues: [Issue], groupName: String) {
        self.id = UUID().uuidString
        self.issues = issues
        self.groupName = groupName
    }

    var isSingle: Bool { issues.count == 1 }
    var isGroup: Bool { issues.count > 1 }

    var displayName: String {
        if let groupName, !groupName.isEmpty { return groupName }
        if let first = issues.first { return first.displayTitle }
        return "Empty"
    }

    /// 드래그용 repo (첫 번째 이슈 기준)
    var primaryRepo: RepoConfig? { issues.first?.repo }
}
