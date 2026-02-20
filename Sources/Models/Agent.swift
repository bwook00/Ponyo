// Sources/Models/Agent.swift
import Foundation

enum Agent: String, Codable, CaseIterable {
    case claudeCode = "claude"
    case codex = "codex"

    var displayName: String {
        switch self {
        case .claudeCode: "CC"
        case .codex: "Codex"
        }
    }

    var command: String { rawValue }
}
