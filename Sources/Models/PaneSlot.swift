// Sources/Models/PaneSlot.swift
import Foundation

enum PaneStatus: String, Codable {
    case idle
    case running
    case crashed
}

struct PaneSlot: Codable, Identifiable {
    var id: String { paneId }
    let paneId: String
    var agent: Agent
    var taskItem: TaskItem?
    var status: PaneStatus = .idle

    var tmuxTitle: String? {
        guard let taskItem else { return nil }
        if taskItem.isGroup {
            return "\(agent.displayName) | \(taskItem.displayName) (\(taskItem.issues.count) issues)"
        }
        guard let issue = taskItem.issues.first else { return nil }
        return "\(agent.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
    }

    var isEmpty: Bool { taskItem == nil }
}
