// Sources/Models/AppState.swift
import Foundation

struct AppState: Codable {
    var repos: [RepoConfig]
    var taskPool: [Issue]
    var paneSlots: [PaneSlot]
    var tmuxSession: String = "ponyo"
}
