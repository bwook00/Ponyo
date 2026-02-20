// Tests/PonyoTests/StateStoreTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct StateStoreTests {
    @Test func saveAndLoad() async throws {
        let tmpPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-state-test-\(UUID().uuidString)")
            .path
        defer { try? FileManager.default.removeItem(atPath: tmpPath) }

        let store = StateStore(directory: tmpPath)
        let state = AppState(
            repos: [RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp")],
            taskPool: [],
            paneSlots: [PaneSlot(paneId: "0", agent: .claudeCode)]
        )

        try await store.save(state)
        let loaded = try await store.load()

        #expect(loaded.repos.count == 1)
        #expect(loaded.repos[0].name == "repo-A")
        #expect(loaded.paneSlots.count == 1)
        #expect(loaded.paneSlots[0].agent == .claudeCode)
    }

    @Test func loadReturnsDefaultWhenNoFile() async throws {
        let tmpPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-nonexistent-\(UUID().uuidString)")
            .path
        let store = StateStore(directory: tmpPath)
        let state = try await store.load()
        #expect(state.repos.isEmpty)
        #expect(state.taskPool.isEmpty)
        #expect(state.paneSlots.isEmpty)
    }

    @Test func saveCreatesDirectory() async throws {
        let tmpPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-mkdir-test-\(UUID().uuidString)/nested/dir")
            .path
        defer {
            // Clean up the top-level temp dir
            let topDir = (tmpPath as NSString).deletingLastPathComponent
            let topTopDir = (topDir as NSString).deletingLastPathComponent
            try? FileManager.default.removeItem(atPath: topTopDir)
        }

        let store = StateStore(directory: tmpPath)
        let state = AppState(repos: [], taskPool: [], paneSlots: [])
        try await store.save(state)

        // Verify file was created
        let fileExists = FileManager.default.fileExists(atPath: "\(tmpPath)/state.json")
        #expect(fileExists == true)
    }
}
