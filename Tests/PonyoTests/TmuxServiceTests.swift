// Tests/PonyoTests/TmuxServiceTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct TmuxServiceTests {
    let service = TmuxService(shell: ShellRunner(), session: "ponyo-test")

    @Test func sessionLifecycle() async throws {
        // Clean up any leftover session first
        try? await service.killSession()

        try await service.createSession()
        let exists = try await service.sessionExists()
        #expect(exists == true)

        try await service.killSession()
        let existsAfter = try await service.sessionExists()
        #expect(existsAfter == false)
    }

    @Test func paneManagement() async throws {
        // Clean up any leftover session first
        try? await service.killSession()

        try await service.createSession()
        defer { Task { try? await service.killSession() } }

        var panes = try await service.listPanes()
        #expect(panes.count == 1)

        let newPaneId = try await service.createPane()
        panes = try await service.listPanes()
        #expect(panes.count == 2)

        try await service.killPane(newPaneId)
        panes = try await service.listPanes()
        #expect(panes.count == 1)
    }

    @Test func setPaneTitle() async throws {
        // Clean up any leftover session first
        try? await service.killSession()

        try await service.createSession()
        defer { Task { try? await service.killSession() } }

        let panes = try await service.listPanes()
        let paneId = panes[0].id
        try await service.setPaneTitle(paneId, title: "CC | repo-A | feat/42")

        let updatedPanes = try await service.listPanes()
        #expect(updatedPanes[0].title == "CC | repo-A | feat/42")
    }
}
