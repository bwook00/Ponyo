// Sources/Services/StateStore.swift
import Foundation

actor StateStore {
    private let directory: String
    private var filePath: String { "\(directory)/state.json" }

    init(directory: String = "\(NSHomeDirectory())/.ponyo") {
        self.directory = directory
    }

    func save(_ state: AppState) async throws {
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: filePath))
    }

    func load() async throws -> AppState {
        guard FileManager.default.fileExists(atPath: filePath) else {
            return AppState(repos: [], taskPool: [], todayTasks: [], paneSlots: [])
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        return try JSONDecoder().decode(AppState.self, from: data)
    }
}
