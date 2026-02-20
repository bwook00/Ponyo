// Tests/PonyoTests/AgentLauncherTests.swift
import Testing
import Foundation
@testable import Ponyo

@Test func buildCCCommand() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "Implement login", labels: [], repo: repo)
    let cmd = AgentLauncher.buildCommand(agent: .claudeCode, issue: issue)
    #expect(cmd.contains("claude"))
    #expect(cmd.contains("#42"))
    #expect(cmd.contains("Add auth"))
}

@Test func buildCodexCommand() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 7, title: "Fix API", body: "Fix endpoint", labels: [], repo: repo)
    let cmd = AgentLauncher.buildCommand(agent: .codex, issue: issue)
    #expect(cmd.contains("codex"))
    #expect(cmd.contains("#7"))
}
