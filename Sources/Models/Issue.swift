// Sources/Models/Issue.swift
import Foundation

struct Issue: Codable, Identifiable, Hashable {
    var id: String { identifier }
    let number: Int
    let title: String
    let body: String
    let labels: [String]
    let repo: RepoConfig

    var identifier: String { "\(repo.name)--issue-\(number)" }
    var branchName: String { "feat/issue-\(number)" }
    var displayTitle: String { "#\(number) \(title)" }
    var worktreePath: String {
        "\(NSHomeDirectory())/.ponyo/worktrees/\(identifier)"
    }
}
