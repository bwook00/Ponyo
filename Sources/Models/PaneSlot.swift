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
    var issue: Issue?
    var status: PaneStatus = .idle

    var worktreePath: String? {
        issue?.worktreePath
    }

    var tmuxTitle: String? {
        guard let issue else { return nil }
        return "\(agent.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
    }

    var isEmpty: Bool { issue == nil }
}
