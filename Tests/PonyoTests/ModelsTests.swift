// Tests/PonyoTests/ModelsTests.swift
import Testing
import Foundation
@testable import Ponyo

@Test func issueIdentifier() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "Details", labels: ["enhancement"], repo: repo)
    #expect(issue.identifier == "repo-A--issue-42")
    #expect(issue.branchName == "feat/issue-42")
    #expect(issue.displayTitle == "#42 Add auth")
}

@Test func issueWorktreePath() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "", labels: [], repo: repo)
    #expect(issue.worktreePath == "\(NSHomeDirectory())/.ponyo/worktrees/repo-A--issue-42")
}

@Test func paneSlotTmuxTitle() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "", labels: [], repo: repo)
    var slot = PaneSlot(paneId: "0", agent: .claudeCode)
    slot.issue = issue
    #expect(slot.tmuxTitle == "CC | repo-A | feat/issue-42 | #42 Add auth")
}

@Test func paneSlotEmptyWhenNoIssue() {
    let slot = PaneSlot(paneId: "0", agent: .claudeCode)
    #expect(slot.isEmpty == true)
    #expect(slot.worktreePath == nil)
    #expect(slot.tmuxTitle == nil)
}

@Test func appStateCodable() throws {
    let state = AppState(
        repos: [RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp")],
        taskPool: [],
        paneSlots: []
    )
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(AppState.self, from: data)
    #expect(decoded.repos.count == 1)
    #expect(decoded.repos[0].name == "repo-A")
}

@Test func agentProperties() {
    #expect(Agent.claudeCode.displayName == "CC")
    #expect(Agent.codex.displayName == "Codex")
    #expect(Agent.claudeCode.command == "claude")
    #expect(Agent.codex.command == "codex")
}
