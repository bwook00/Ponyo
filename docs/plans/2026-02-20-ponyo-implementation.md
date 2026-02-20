# Ponyo Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** tmux 페인을 시각적으로 관리하고, GitHub Issues를 드래그 앤 드롭으로 배치하면 git worktree 생성 + Agent 실행까지 자동 수행하는 네이티브 macOS 앱.

**Architecture:** MVVM + Services. SwiftUI 앱이 메뉴바 + 독립 창 두 모드를 지원. 모든 외부 도구(tmux, git, gh)는 Swift Process로 CLI 호출. 상태는 ~/.ponyo/state.json에 영속.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 15+, SPM (외부 의존성 0개)

**Design doc:** `docs/plans/2026-02-20-ponyo-app-design.md`

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/PonyoApp.swift`
- Create: `Sources/Models/.gitkeep`
- Create: `Sources/Services/.gitkeep`
- Create: `Sources/ViewModels/.gitkeep`
- Create: `Sources/Views/.gitkeep`
- Create: `Tests/PonyoTests/.gitkeep`

**Step 1: Create Package.swift**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ponyo",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Ponyo",
            path: "Sources"
        ),
        .testTarget(
            name: "PonyoTests",
            dependencies: ["Ponyo"],
            path: "Tests"
        )
    ]
)
```

**Step 2: Create minimal app entry point**

```swift
// Sources/PonyoApp.swift
import SwiftUI

@main
struct PonyoApp: App {
    var body: some Scene {
        MenuBarExtra("Ponyo", systemImage: "fish") {
            Text("Ponyo is running")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
```

**Step 3: Build and verify**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "feat: scaffold SPM project with minimal menu bar app"
```

---

### Task 2: Core Data Models

**Files:**
- Create: `Sources/Models/Agent.swift`
- Create: `Sources/Models/RepoConfig.swift`
- Create: `Sources/Models/Issue.swift`
- Create: `Sources/Models/PaneSlot.swift`
- Create: `Sources/Models/AppState.swift`
- Create: `Tests/ModelsTests.swift`

**Step 1: Write failing tests for models**

```swift
// Tests/ModelsTests.swift
import Testing
@testable import Ponyo

@Test func issueIdentifier() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "Details", labels: ["enhancement"], repo: repo)
    #expect(issue.identifier == "repo-A--issue-42")
    #expect(issue.branchName == "feat/issue-42")
    #expect(issue.displayTitle == "#42 Add auth")
}

@Test func paneSlotWorktreePath() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "", labels: [], repo: repo)
    var slot = PaneSlot(paneId: "0", agent: .claudeCode)
    slot.issue = issue
    #expect(slot.worktreePath == "\(NSHomeDirectory())/.ponyo/worktrees/repo-A--issue-42")
}

@Test func paneSlotTmuxTitle() {
    let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp/repo-A")
    let issue = Issue(number: 42, title: "Add auth", body: "", labels: [], repo: repo)
    var slot = PaneSlot(paneId: "0", agent: .claudeCode)
    slot.issue = issue
    #expect(slot.tmuxTitle == "CC | repo-A | feat/issue-42 | #42 Add auth")
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
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ModelsTests`
Expected: FAIL - types not defined

**Step 3: Implement models**

```swift
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
```

```swift
// Sources/Models/RepoConfig.swift
import Foundation

struct RepoConfig: Codable, Identifiable, Hashable {
    var id: String { "\(owner)/\(name)" }
    let owner: String
    let name: String
    let localPath: String
}
```

```swift
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
```

```swift
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
```

```swift
// Sources/Models/AppState.swift
import Foundation

struct AppState: Codable {
    var repos: [RepoConfig]
    var taskPool: [Issue]
    var paneSlots: [PaneSlot]
    var tmuxSession: String = "ponyo"
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ModelsTests`
Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add Sources/Models/ Tests/ModelsTests.swift
git commit -m "feat: add core data models with tests"
```

---

### Task 3: ShellRunner (Process Abstraction)

Agent들과 tmux, git을 모두 Process로 호출하므로 공통 추상화가 필요.

**Files:**
- Create: `Sources/Services/ShellRunner.swift`
- Create: `Tests/ShellRunnerTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/ShellRunnerTests.swift
import Testing
@testable import Ponyo

@Test func shellRunnerEcho() async throws {
    let runner = ShellRunner()
    let output = try await runner.run("echo", arguments: ["hello"])
    #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

@Test func shellRunnerFailure() async {
    let runner = ShellRunner()
    do {
        _ = try await runner.run("/usr/bin/false")
        #expect(Bool(false), "Should have thrown")
    } catch let error as ShellError {
        #expect(error.exitCode != 0)
    } catch {
        #expect(Bool(false), "Wrong error type: \(error)")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ShellRunnerTests`
Expected: FAIL

**Step 3: Implement ShellRunner**

```swift
// Sources/Services/ShellRunner.swift
import Foundation

struct ShellError: Error {
    let exitCode: Int32
    let stderr: String
}

actor ShellRunner {
    func run(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw ShellError(
                exitCode: process.terminationStatus,
                stderr: String(data: stderrData, encoding: .utf8) ?? ""
            )
        }

        return String(data: stdoutData, encoding: .utf8) ?? ""
    }

    /// command가 PATH에 있는 경우 /usr/bin/env를 통해 실행
    func runCommand(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) async throws -> String {
        try await run("/usr/bin/env", arguments: [command] + arguments, workingDirectory: workingDirectory)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ShellRunnerTests`
Expected: All 2 tests PASS

**Step 5: Commit**

```bash
git add Sources/Services/ShellRunner.swift Tests/ShellRunnerTests.swift
git commit -m "feat: add ShellRunner process abstraction"
```

---

### Task 4: TmuxService

**Files:**
- Create: `Sources/Services/TmuxService.swift`
- Create: `Tests/TmuxServiceTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/TmuxServiceTests.swift
import Testing
@testable import Ponyo

// 실제 tmux 세션을 사용하는 통합 테스트
// 테스트 전후에 임시 세션 생성/삭제
@Suite(.serialized)
struct TmuxServiceTests {
    let service = TmuxService(shell: ShellRunner(), session: "ponyo-test")

    @Test func sessionLifecycle() async throws {
        // 세션 생성
        try await service.createSession()
        let exists = try await service.sessionExists()
        #expect(exists == true)

        // 세션 삭제
        try await service.killSession()
        let existsAfter = try await service.sessionExists()
        #expect(existsAfter == false)
    }

    @Test func paneManagement() async throws {
        try await service.createSession()
        defer { Task { try? await service.killSession() } }

        // 초기 페인 1개
        var panes = try await service.listPanes()
        #expect(panes.count == 1)

        // 페인 추가
        let newPaneId = try await service.createPane()
        panes = try await service.listPanes()
        #expect(panes.count == 2)

        // 페인 삭제
        try await service.killPane(newPaneId)
        panes = try await service.listPanes()
        #expect(panes.count == 1)
    }

    @Test func sendKeysAndPaneTitle() async throws {
        try await service.createSession()
        defer { Task { try? await service.killSession() } }

        let panes = try await service.listPanes()
        let paneId = panes[0].id
        try await service.setPaneTitle(paneId, title: "CC | repo-A | feat/42")

        // 타이틀 확인
        let updatedPanes = try await service.listPanes()
        #expect(updatedPanes[0].title == "CC | repo-A | feat/42")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter TmuxServiceTests`
Expected: FAIL

**Step 3: Implement TmuxService**

```swift
// Sources/Services/TmuxService.swift
import Foundation

struct TmuxPaneInfo {
    let id: String       // e.g. "%0"
    let index: Int
    let pid: Int
    let command: String  // e.g. "zsh", "claude", "codex"
    let title: String
}

actor TmuxService {
    private let shell: ShellRunner
    let session: String

    init(shell: ShellRunner, session: String = "ponyo") {
        self.shell = shell
        self.session = session
    }

    func sessionExists() async throws -> Bool {
        do {
            _ = try await shell.runCommand("tmux", arguments: ["has-session", "-t", session])
            return true
        } catch {
            return false
        }
    }

    func createSession() async throws {
        _ = try await shell.runCommand("tmux", arguments: ["new-session", "-d", "-s", session])
    }

    func killSession() async throws {
        _ = try await shell.runCommand("tmux", arguments: ["kill-session", "-t", session])
    }

    func listPanes() async throws -> [TmuxPaneInfo] {
        let format = "#{pane_id}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}"
        let output = try await shell.runCommand(
            "tmux", arguments: ["list-panes", "-t", session, "-F", format]
        )
        return output
            .split(separator: "\n")
            .compactMap { line -> TmuxPaneInfo? in
                let parts = line.split(separator: "\t", maxSplits: 4).map(String.init)
                guard parts.count == 5, let index = Int(parts[1]), let pid = Int(parts[2]) else { return nil }
                return TmuxPaneInfo(id: parts[0], index: index, pid: pid, command: parts[3], title: parts[4])
            }
    }

    func createPane() async throws -> String {
        let output = try await shell.runCommand(
            "tmux", arguments: ["split-window", "-t", session, "-P", "-F", "#{pane_id}"]
        )
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func killPane(_ paneId: String) async throws {
        _ = try await shell.runCommand("tmux", arguments: ["kill-pane", "-t", paneId])
    }

    func sendKeys(_ paneId: String, keys: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["send-keys", "-t", paneId, keys, "Enter"]
        )
    }

    func setPaneTitle(_ paneId: String, title: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["select-pane", "-t", paneId, "-T", title]
        )
    }

    func sendCtrlC(_ paneId: String) async throws {
        _ = try await shell.runCommand(
            "tmux", arguments: ["send-keys", "-t", paneId, "C-c"]
        )
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter TmuxServiceTests`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add Sources/Services/TmuxService.swift Tests/TmuxServiceTests.swift
git commit -m "feat: add TmuxService for pane management"
```

---

### Task 5: GitService

**Files:**
- Create: `Sources/Services/GitService.swift`
- Create: `Tests/GitServiceTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/GitServiceTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct GitServiceTests {
    let service = GitService(shell: ShellRunner())

    /// 임시 git repo를 만들어서 worktree 테스트
    @Test func worktreeLifecycle() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-test-\(UUID().uuidString)")
        let repoPath = tmpDir.appendingPathComponent("repo").path
        let worktreePath = tmpDir.appendingPathComponent("wt").path

        // setup: git init + initial commit
        let shell = ShellRunner()
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        _ = try await shell.runCommand("git", arguments: ["init"], workingDirectory: repoPath)
        _ = try await shell.runCommand("git", arguments: [
            "commit", "--allow-empty", "-m", "init"
        ], workingDirectory: repoPath)

        defer { try? FileManager.default.removeItem(atPath: tmpDir.path) }

        // worktree 추가
        try await service.addWorktree(repoPath: repoPath, branchName: "feat/test", targetPath: worktreePath)
        #expect(FileManager.default.fileExists(atPath: worktreePath))

        // worktree 목록 확인
        let worktrees = try await service.listWorktrees(repoPath: repoPath)
        #expect(worktrees.contains(where: { $0.contains("wt") }))

        // worktree 삭제
        try await service.removeWorktree(repoPath: repoPath, worktreePath: worktreePath)
        #expect(!FileManager.default.fileExists(atPath: worktreePath))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter GitServiceTests`
Expected: FAIL

**Step 3: Implement GitService**

```swift
// Sources/Services/GitService.swift
import Foundation

actor GitService {
    private let shell: ShellRunner

    init(shell: ShellRunner) {
        self.shell = shell
    }

    func addWorktree(repoPath: String, branchName: String, targetPath: String) async throws {
        _ = try await shell.runCommand(
            "git", arguments: ["worktree", "add", targetPath, "-b", branchName],
            workingDirectory: repoPath
        )
    }

    func removeWorktree(repoPath: String, worktreePath: String) async throws {
        _ = try await shell.runCommand(
            "git", arguments: ["worktree", "remove", worktreePath, "--force"],
            workingDirectory: repoPath
        )
    }

    func listWorktrees(repoPath: String) async throws -> [String] {
        let output = try await shell.runCommand(
            "git", arguments: ["worktree", "list", "--porcelain"],
            workingDirectory: repoPath
        )
        return output
            .split(separator: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .map { String($0.dropFirst("worktree ".count)) }
    }

    /// worktree가 이미 존재하는지 확인
    func worktreeExists(repoPath: String, targetPath: String) async throws -> Bool {
        let worktrees = try await listWorktrees(repoPath: repoPath)
        return worktrees.contains(targetPath)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter GitServiceTests`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Sources/Services/GitService.swift Tests/GitServiceTests.swift
git commit -m "feat: add GitService for worktree management"
```

---

### Task 6: GitHubService

**Files:**
- Create: `Sources/Services/GitHubService.swift`
- Create: `Tests/GitHubServiceTests.swift`

**Step 1: Write failing tests (mock URLProtocol 기반)**

```swift
// Tests/GitHubServiceTests.swift
import Testing
import Foundation
@testable import Ponyo

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!.absoluteString
        if let (data, response) = Self.mockResponses[url] {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct GitHubServiceTests {
    @Test func fetchIssues() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = GitHubService(token: "fake-token", urlSession: session)

        let issuesJSON = """
        [{"number": 42, "title": "Add auth", "body": "Details", "labels": [{"name": "enhancement"}]}]
        """
        let url = "https://api.github.com/repos/user/repo-A/issues?state=open&per_page=100"
        MockURLProtocol.mockResponses[url] = (
            issuesJSON.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp")
        let issues = try await service.fetchIssues(repo: repo)

        #expect(issues.count == 1)
        #expect(issues[0].number == 42)
        #expect(issues[0].title == "Add auth")
        #expect(issues[0].labels == ["enhancement"])
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter GitHubServiceTests`
Expected: FAIL

**Step 3: Implement GitHubService**

```swift
// Sources/Services/GitHubService.swift
import Foundation

actor GitHubService {
    private let token: String
    private let urlSession: URLSession
    private let baseURL = "https://api.github.com"

    init(token: String, urlSession: URLSession = .shared) {
        self.token = token
        self.urlSession = urlSession
    }

    func fetchIssues(repo: RepoConfig) async throws -> [Issue] {
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues?state=open&per_page=100")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await urlSession.data(for: request)
        let decoded = try JSONDecoder().decode([GitHubIssue].self, from: data)

        return decoded.map { gh in
            Issue(
                number: gh.number,
                title: gh.title,
                body: gh.body ?? "",
                labels: gh.labels.map(\.name),
                repo: repo
            )
        }
    }

    func addLabel(repo: RepoConfig, issueNumber: Int, label: String) async throws {
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues/\(issueNumber)/labels")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["labels": [label]])
        _ = try await urlSession.data(for: request)
    }

    func removeLabel(repo: RepoConfig, issueNumber: Int, label: String) async throws {
        let encoded = label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? label
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues/\(issueNumber)/labels/\(encoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await urlSession.data(for: request)
    }
}

// GitHub API response types (internal)
private struct GitHubIssue: Decodable {
    let number: Int
    let title: String
    let body: String?
    let labels: [GitHubLabel]
}

private struct GitHubLabel: Decodable {
    let name: String
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter GitHubServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Services/GitHubService.swift Tests/GitHubServiceTests.swift
git commit -m "feat: add GitHubService for issues and labels"
```

---

### Task 7: StateStore

**Files:**
- Create: `Sources/Services/StateStore.swift`
- Create: `Tests/StateStoreTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/StateStoreTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct StateStoreTests {
    @Test func saveAndLoad() async throws {
        let tmpPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-test-\(UUID().uuidString)")
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
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter StateStoreTests`
Expected: FAIL

**Step 3: Implement StateStore**

```swift
// Sources/Services/StateStore.swift
import Foundation

actor StateStore {
    private let directory: String
    private var filePath: String { "\(directory)/state.json" }

    init(directory: String = "\(NSHomeDirectory())/.ponyo") {
        self.directory = directory
    }

    func save(_ state: AppState) async throws {
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: URL(fileURLWithPath: filePath))
    }

    func load() async throws -> AppState {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            return AppState(repos: [], taskPool: [], paneSlots: [])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppState.self, from: data)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter StateStoreTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Services/StateStore.swift Tests/StateStoreTests.swift
git commit -m "feat: add StateStore for JSON state persistence"
```

---

### Task 8: AgentLauncher

**Files:**
- Create: `Sources/Services/AgentLauncher.swift`
- Create: `Tests/AgentLauncherTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/AgentLauncherTests.swift
import Testing
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
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter AgentLauncherTests`
Expected: FAIL

**Step 3: Implement AgentLauncher**

```swift
// Sources/Services/AgentLauncher.swift
import Foundation

struct AgentLauncher {
    private let tmux: TmuxService
    private let git: GitService

    init(tmux: TmuxService, git: GitService) {
        self.tmux = tmux
        self.git = git
    }

    static func buildCommand(agent: Agent, issue: Issue) -> String {
        let prompt = "Fix \\#\(issue.number): \(issue.title)\\n\\n\(issue.body)"
            .replacingOccurrences(of: "'", with: "'\\''")
        return "\(agent.command) '\(prompt)'"
    }

    /// 이슈를 페인에 배치하고 Agent 실행
    func launch(paneId: String, agent: Agent, issue: Issue) async throws {
        let worktreePath = issue.worktreePath

        // 1. worktree가 없으면 생성
        let exists = try await git.worktreeExists(
            repoPath: issue.repo.localPath,
            targetPath: worktreePath
        )
        if !exists {
            try await git.addWorktree(
                repoPath: issue.repo.localPath,
                branchName: issue.branchName,
                targetPath: worktreePath
            )
        }

        // 2. 디렉토리 이동
        try await tmux.sendKeys(paneId, keys: "cd \(worktreePath)")

        // 3. 잠시 대기 후 Agent 실행
        try await Task.sleep(for: .milliseconds(500))
        let command = Self.buildCommand(agent: agent, issue: issue)
        try await tmux.sendKeys(paneId, keys: command)

        // 4. 페인 타이틀 설정
        let title = "\(agent.displayName) | \(issue.repo.name) | \(issue.branchName) | \(issue.displayTitle)"
        try await tmux.setPaneTitle(paneId, title: title)
    }

    /// Agent 중단
    func stop(paneId: String) async throws {
        try await tmux.sendCtrlC(paneId)
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter AgentLauncherTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/Services/AgentLauncher.swift Tests/AgentLauncherTests.swift
git commit -m "feat: add AgentLauncher for agent execution"
```

---

### Task 9: PaneMonitor

**Files:**
- Create: `Sources/Services/PaneMonitor.swift`

**Step 1: Implement PaneMonitor (Timer 기반)**

```swift
// Sources/Services/PaneMonitor.swift
import Foundation
import Combine

@MainActor
final class PaneMonitor: ObservableObject {
    @Published var paneInfos: [TmuxPaneInfo] = []
    private let tmux: TmuxService
    private var timer: Timer?

    init(tmux: TmuxService) {
        self.tmux = tmux
    }

    func start(interval: TimeInterval = 2.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() async {
        do {
            paneInfos = try await tmux.listPanes()
        } catch {
            paneInfos = []
        }
    }

    /// pane_current_command로 Agent 상태 판별
    func agentStatus(for paneId: String) -> PaneStatus {
        guard let info = paneInfos.first(where: { $0.id == paneId }) else {
            return .idle
        }
        let agentCommands = Set(Agent.allCases.map(\.command))
        if agentCommands.contains(info.command) {
            return .running
        }
        return .idle
    }
}
```

**Step 2: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/Services/PaneMonitor.swift
git commit -m "feat: add PaneMonitor for polling pane status"
```

---

### Task 10: DashboardViewModel

**Files:**
- Create: `Sources/ViewModels/DashboardViewModel.swift`

**Step 1: Implement DashboardViewModel**

```swift
// Sources/ViewModels/DashboardViewModel.swift
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: AppState
    @Published var isLoading = false

    let tmux: TmuxService
    let git: GitService
    let github: GitHubService
    let launcher: AgentLauncher
    let stateStore: StateStore
    let monitor: PaneMonitor

    init(
        tmux: TmuxService,
        git: GitService,
        github: GitHubService,
        stateStore: StateStore,
        monitor: PaneMonitor
    ) {
        self.tmux = tmux
        self.git = git
        self.github = github
        self.launcher = AgentLauncher(tmux: tmux, git: git)
        self.stateStore = stateStore
        self.monitor = monitor
        self.state = AppState(repos: [], taskPool: [], paneSlots: [])
    }

    // MARK: - Lifecycle

    func onAppear() async {
        // 1. 상태 복원
        if let loaded = try? await stateStore.load() {
            state = loaded
        }

        // 2. tmux 세션 확인/생성
        let exists = (try? await tmux.sessionExists()) ?? false
        if !exists {
            try? await tmux.createSession()
        }

        // 3. 모니터 시작
        monitor.start()
    }

    // MARK: - Task Pool

    func fetchIssues() async {
        isLoading = true
        defer { isLoading = false }

        var allIssues: [Issue] = []
        for repo in state.repos {
            if let issues = try? await github.fetchIssues(repo: repo) {
                allIssues.append(contentsOf: issues)
            }
        }
        state.taskPool = allIssues
        try? await stateStore.save(state)
    }

    // MARK: - Pane Management

    func addPane() async {
        do {
            let paneId = try await tmux.createPane()
            let slot = PaneSlot(paneId: paneId, agent: .claudeCode)
            state.paneSlots.append(slot)
            try? await stateStore.save(state)
        } catch {}
    }

    /// 이슈를 페인에 배치 (드래그 앤 드롭 완료 시)
    func assignIssue(_ issue: Issue, toPaneAt index: Int, agent: Agent) async {
        guard index < state.paneSlots.count else { return }

        // TaskPool에서 제거
        state.taskPool.removeAll { $0.id == issue.id }

        // PaneSlot에 배치
        state.paneSlots[index].issue = issue
        state.paneSlots[index].agent = agent
        state.paneSlots[index].status = .running

        // Agent 실행
        let paneId = state.paneSlots[index].paneId
        try? await launcher.launch(paneId: paneId, agent: agent, issue: issue)

        // GitHub 라벨 추가
        try? await github.addLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        try? await stateStore.save(state)
    }

    /// 되돌리기: 이슈를 TaskPool로
    func returnToPool(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let issue = state.paneSlots[paneIndex].issue else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // TaskPool로 되돌림
        state.taskPool.append(issue)
        state.paneSlots[paneIndex].issue = nil
        state.paneSlots[paneIndex].status = .idle

        // GitHub 라벨 제거
        try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        try? await stateStore.save(state)
    }

    /// 완료: worktree 삭제, 페인 삭제
    func completeTask(paneIndex: Int) async {
        guard paneIndex < state.paneSlots.count,
              let issue = state.paneSlots[paneIndex].issue else { return }

        let paneId = state.paneSlots[paneIndex].paneId
        try? await launcher.stop(paneId: paneId)

        // worktree 삭제 (브랜치는 유지)
        try? await git.removeWorktree(repoPath: issue.repo.localPath, worktreePath: issue.worktreePath)

        // 페인 삭제
        try? await tmux.killPane(paneId)

        // GitHub 라벨 제거
        try? await github.removeLabel(repo: issue.repo, issueNumber: issue.number, label: "in-progress")

        // 슬롯 제거
        state.paneSlots.remove(at: paneIndex)
        try? await stateStore.save(state)
    }

    // MARK: - Status Sync

    func syncPaneStatuses() {
        for i in state.paneSlots.indices {
            let paneId = state.paneSlots[i].paneId
            state.paneSlots[i].status = monitor.agentStatus(for: paneId)
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Sources/ViewModels/DashboardViewModel.swift
git commit -m "feat: add DashboardViewModel with full orchestration logic"
```

---

### Task 11: MenuBarView + App Entry Point

**Files:**
- Modify: `Sources/PonyoApp.swift`
- Create: `Sources/Views/MenuBarView.swift`

**Step 1: Implement MenuBarView**

```swift
// Sources/Views/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks: \(vm.state.taskPool.count) remaining")
                .font(.headline)

            let running = vm.state.paneSlots.filter { $0.status == .running }.count
            let idle = vm.state.paneSlots.filter { $0.status == .idle }.count
            Text("Panes: \(running) running, \(idle) idle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            ForEach(vm.state.paneSlots) { slot in
                HStack {
                    Circle()
                        .fill(statusColor(slot.status))
                        .frame(width: 8, height: 8)
                    Text(slot.tmuxTitle ?? "Empty pane")
                        .lineLimit(1)
                }
                .font(.caption)
            }

            if vm.state.paneSlots.isEmpty {
                Text("No active panes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "dashboard" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Refresh Issues") {
                Task { await vm.fetchIssues() }
            }

            Divider()

            Button("Quit Ponyo") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 280)
    }

    private func statusColor(_ status: PaneStatus) -> Color {
        switch status {
        case .running: .green
        case .idle: .yellow
        case .crashed: .red
        }
    }
}
```

**Step 2: Update PonyoApp.swift**

```swift
// Sources/PonyoApp.swift
import SwiftUI

@main
struct PonyoApp: App {
    @StateObject private var vm: DashboardViewModel

    init() {
        let shell = ShellRunner()
        let tmux = TmuxService(shell: shell)
        let git = GitService(shell: shell)
        let stateStore = StateStore()
        let monitor = PaneMonitor(tmux: tmux)

        // 토큰은 Keychain에서 로드 (Settings에서 설정)
        let token = KeychainHelper.load(key: "github-token") ?? ""
        let github = GitHubService(token: token)

        let vm = DashboardViewModel(
            tmux: tmux, git: git, github: github,
            stateStore: stateStore, monitor: monitor
        )
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some Scene {
        MenuBarExtra("Ponyo", systemImage: "fish") {
            MenuBarView(vm: vm)
        }

        Window("Ponyo Dashboard", id: "dashboard") {
            DashboardView(vm: vm)
        }
        .defaultSize(width: 900, height: 600)
    }
}
```

**Step 3: Create KeychainHelper stub**

```swift
// Sources/Services/KeychainHelper.swift
import Foundation
import Security

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.ponyo.app",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.ponyo.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.ponyo.app"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

**Step 4: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/PonyoApp.swift Sources/Views/MenuBarView.swift Sources/Services/KeychainHelper.swift
git commit -m "feat: add menu bar view and app entry point with Keychain"
```

---

### Task 12: DashboardView + TaskPoolView

**Files:**
- Create: `Sources/Views/DashboardView.swift`
- Create: `Sources/Views/TaskPoolView.swift`
- Create: `Sources/Views/TaskCardView.swift`

**Step 1: Implement TaskCardView**

```swift
// Sources/Views/TaskCardView.swift
import SwiftUI

struct TaskCardView: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(issue.repo.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(issue.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(10)
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
```

**Step 2: Implement TaskPoolView**

```swift
// Sources/Views/TaskPoolView.swift
import SwiftUI

struct TaskPoolView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Tasks", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await vm.fetchIssues() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }

            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if vm.state.taskPool.isEmpty {
                ContentUnavailableView(
                    "No tasks",
                    systemImage: "tray",
                    description: Text("Fetch issues from your repos")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.state.taskPool) { issue in
                            TaskCardView(issue: issue)
                                .draggable(issue.id) // String transferable
                        }
                    }
                }
            }

            Divider()

            // Repo 관리
            VStack(alignment: .leading, spacing: 4) {
                Text("Repos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(vm.state.repos) { repo in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(repo.id)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}
```

**Step 3: Implement DashboardView (layout shell)**

```swift
// Sources/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        HSplitView {
            TaskPoolView(vm: vm)
                .frame(minWidth: 250, maxWidth: 350)

            PaneGridView(vm: vm)
                .frame(minWidth: 400)
        }
        .task { await vm.onAppear() }
        .onReceive(vm.monitor.$paneInfos) { _ in
            vm.syncPaneStatuses()
        }
    }
}
```

**Step 4: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/Views/DashboardView.swift Sources/Views/TaskPoolView.swift Sources/Views/TaskCardView.swift
git commit -m "feat: add Dashboard, TaskPool, and TaskCard views"
```

---

### Task 13: PaneGridView + PaneCardView + Drag & Drop

**Files:**
- Create: `Sources/Views/PaneGridView.swift`
- Create: `Sources/Views/PaneCardView.swift`

**Step 1: Implement PaneCardView**

```swift
// Sources/Views/PaneCardView.swift
import SwiftUI

struct PaneCardView: View {
    let slot: PaneSlot
    let paneIndex: Int
    let onReturn: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더: Agent + Status
            HStack {
                Text(slot.agent.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(slot.agent == .claudeCode ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2))
                    .cornerRadius(4)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(slot.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let issue = slot.issue {
                // Issue 정보
                Text(issue.repo.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(issue.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(issue.branchName)
                    .font(.caption2)
                    .foregroundStyle(.blue)

                // 액션 버튼
                HStack {
                    Button(action: onReturn) {
                        Label("Return", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onComplete) {
                        Label("Done", systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                // 빈 페인
                VStack {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Drop task here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(12)
        .background(.background)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusBorderColor, lineWidth: slot.isEmpty ? 1 : 2)
        )
    }

    private var statusColor: Color {
        switch slot.status {
        case .running: .green
        case .idle: .yellow
        case .crashed: .red
        }
    }

    private var statusBorderColor: Color {
        slot.isEmpty ? Color.secondary.opacity(0.3) : statusColor.opacity(0.5)
    }
}
```

**Step 2: Implement PaneGridView with Drag & Drop**

```swift
// Sources/Views/PaneGridView.swift
import SwiftUI

struct PaneGridView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var showAgentPicker = false
    @State private var pendingDrop: (issueId: String, paneIndex: Int)?
    @State private var selectedAgent: Agent = .claudeCode

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Panes", systemImage: "rectangle.split.2x2")
                    .font(.headline)
                Spacer()
                statusSummary
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(vm.state.paneSlots.enumerated()), id: \.element.id) { index, slot in
                        PaneCardView(
                            slot: slot,
                            paneIndex: index,
                            onReturn: { Task { await vm.returnToPool(paneIndex: index) } },
                            onComplete: { Task { await vm.completeTask(paneIndex: index) } }
                        )
                        .dropDestination(for: String.self) { items, _ in
                            guard let issueId = items.first, slot.isEmpty else { return false }
                            pendingDrop = (issueId, index)
                            showAgentPicker = true
                            return true
                        }
                    }

                    // "+ Add Pane" 카드
                    Button(action: { Task { await vm.addPane() } }) {
                        VStack {
                            Image(systemName: "plus.rectangle")
                                .font(.title)
                            Text("Add Pane")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(.secondary.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAgentPicker) {
            AgentPickerSheet(
                selectedAgent: $selectedAgent,
                onLaunch: {
                    guard let drop = pendingDrop,
                          let issue = vm.state.taskPool.first(where: { $0.id == drop.issueId })
                    else { return }
                    Task { await vm.assignIssue(issue, toPaneAt: drop.paneIndex, agent: selectedAgent) }
                    showAgentPicker = false
                    pendingDrop = nil
                },
                onCancel: {
                    showAgentPicker = false
                    pendingDrop = nil
                }
            )
        }
    }

    private var statusSummary: some View {
        HStack(spacing: 12) {
            let running = vm.state.paneSlots.filter { $0.status == .running }.count
            let idle = vm.state.paneSlots.filter { $0.status == .idle }.count
            Label("\(running)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Label("\(idle)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        }
    }
}

struct AgentPickerSheet: View {
    @Binding var selectedAgent: Agent
    let onLaunch: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Which agent?")
                .font(.headline)

            Picker("Agent", selection: $selectedAgent) {
                ForEach(Agent.allCases, id: \.self) { agent in
                    Text(agent.displayName).tag(agent)
                }
            }
            .pickerStyle(.radioGroup)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Launch", action: onLaunch)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 250)
    }
}
```

**Step 3: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/Views/PaneGridView.swift Sources/Views/PaneCardView.swift
git commit -m "feat: add PaneGrid and PaneCard views with drag & drop"
```

---

### Task 14: Settings & Onboarding Views

**Files:**
- Create: `Sources/Views/SettingsView.swift`
- Create: `Sources/Views/OnboardingView.swift`

**Step 1: Implement SettingsView**

```swift
// Sources/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var token: String = ""
    @State private var newRepoOwner = ""
    @State private var newRepoName = ""
    @State private var newRepoPath = ""

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Personal Access Token", text: $token)
                Button("Save Token") {
                    KeychainHelper.save(key: "github-token", value: token)
                }
            }

            Section("Repositories") {
                ForEach(vm.state.repos) { repo in
                    HStack {
                        Text(repo.id)
                        Spacer()
                        Text(repo.localPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            vm.state.repos.removeAll { $0.id == repo.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                HStack {
                    TextField("owner", text: $newRepoOwner)
                        .frame(width: 100)
                    Text("/")
                    TextField("repo", text: $newRepoName)
                        .frame(width: 100)
                    TextField("local path", text: $newRepoPath)
                    Button("Add") {
                        let repo = RepoConfig(
                            owner: newRepoOwner,
                            name: newRepoName,
                            localPath: newRepoPath
                        )
                        vm.state.repos.append(repo)
                        newRepoOwner = ""
                        newRepoName = ""
                        newRepoPath = ""
                        Task { try? await vm.stateStore.save(vm.state) }
                    }
                    .disabled(newRepoOwner.isEmpty || newRepoName.isEmpty || newRepoPath.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            token = KeychainHelper.load(key: "github-token") ?? ""
        }
    }
}
```

**Step 2: Implement OnboardingView**

```swift
// Sources/Views/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var step = 0
    @State private var token = ""
    @State private var repoOwner = ""
    @State private var repoName = ""
    @State private var repoPath = ""
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Progress
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }

            switch step {
            case 0: tokenStep
            case 1: repoStep
            case 2: confirmStep
            default: EmptyView()
            }
        }
        .padding(32)
        .frame(width: 450, height: 350)
    }

    private var tokenStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("GitHub Token")
                .font(.title2)
            Text("Personal Access Token with repo scope")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("ghp_...", text: $token)
                .textFieldStyle(.roundedBorder)
            Button("Next") {
                KeychainHelper.save(key: "github-token", value: token)
                step = 1
            }
            .disabled(token.isEmpty)
            .buttonStyle(.borderedProminent)
        }
    }

    private var repoStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("Add a Repository")
                .font(.title2)
            HStack {
                TextField("owner", text: $repoOwner)
                Text("/")
                TextField("repo", text: $repoName)
            }
            .textFieldStyle(.roundedBorder)
            TextField("Local clone path (e.g. /Users/.../repo)", text: $repoPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Back") { step = 0 }
                Button("Next") {
                    let repo = RepoConfig(owner: repoOwner, name: repoName, localPath: repoPath)
                    vm.state.repos.append(repo)
                    step = 2
                }
                .disabled(repoOwner.isEmpty || repoName.isEmpty || repoPath.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var confirmStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("All Set!")
                .font(.title2)
            Text("You can add more repos in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Start Using Ponyo") {
                Task {
                    try? await vm.stateStore.save(vm.state)
                    await vm.fetchIssues()
                }
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

**Step 3: Update PonyoApp.swift to include Settings and Onboarding**

Modify `Sources/PonyoApp.swift` - add Settings scene and onboarding check:

```swift
// 기존 body에 Settings scene 추가:
Settings {
    SettingsView(vm: vm)
}
```

**Step 4: Build to verify compilation**

Run: `swift build`
Expected: Build succeeds

**Step 5: Commit**

```bash
git add Sources/Views/SettingsView.swift Sources/Views/OnboardingView.swift Sources/PonyoApp.swift
git commit -m "feat: add Settings and Onboarding views"
```

---

### Task 15: Integration Test & Polish

**Files:**
- Create: `Tests/IntegrationTests.swift`

**Step 1: Write end-to-end integration test**

```swift
// Tests/IntegrationTests.swift
import Testing
import Foundation
@testable import Ponyo

@Suite(.serialized)
struct IntegrationTests {
    /// 전체 플로우: worktree 생성 → tmux 페인 생성 → 정리
    @Test func fullWorkflow() async throws {
        let shell = ShellRunner()
        let tmux = TmuxService(shell: shell, session: "ponyo-integration-test")
        let git = GitService(shell: shell)

        // Setup: 임시 git repo
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ponyo-integ-\(UUID().uuidString)")
        let repoPath = tmpDir.appendingPathComponent("repo").path
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        _ = try await shell.runCommand("git", arguments: ["init"], workingDirectory: repoPath)
        _ = try await shell.runCommand("git", arguments: [
            "commit", "--allow-empty", "-m", "init"
        ], workingDirectory: repoPath)

        defer {
            Task {
                try? await tmux.killSession()
                try? FileManager.default.removeItem(atPath: tmpDir.path)
            }
        }

        let repo = RepoConfig(owner: "test", name: "repo", localPath: repoPath)
        let issue = Issue(number: 1, title: "Test issue", body: "body", labels: [], repo: repo)

        // 1. tmux 세션 생성
        try await tmux.createSession()
        let exists = try await tmux.sessionExists()
        #expect(exists)

        // 2. worktree 생성
        try await git.addWorktree(
            repoPath: repoPath,
            branchName: issue.branchName,
            targetPath: issue.worktreePath
        )
        #expect(FileManager.default.fileExists(atPath: issue.worktreePath))

        // 3. 페인 생성
        let panes = try await tmux.listPanes()
        #expect(panes.count >= 1)

        // 4. 정리
        try await git.removeWorktree(repoPath: repoPath, worktreePath: issue.worktreePath)
        #expect(!FileManager.default.fileExists(atPath: issue.worktreePath))

        try await tmux.killSession()
    }
}
```

**Step 2: Run all tests**

Run: `swift test`
Expected: All tests PASS

**Step 3: Commit**

```bash
git add Tests/IntegrationTests.swift
git commit -m "feat: add integration test for full workflow"
```

---

## Summary

| Task | Description | Key Files |
|------|-------------|-----------|
| 1 | Project scaffolding | Package.swift, PonyoApp.swift |
| 2 | Core data models | Models/*.swift |
| 3 | ShellRunner (Process abstraction) | Services/ShellRunner.swift |
| 4 | TmuxService | Services/TmuxService.swift |
| 5 | GitService | Services/GitService.swift |
| 6 | GitHubService | Services/GitHubService.swift |
| 7 | StateStore | Services/StateStore.swift |
| 8 | AgentLauncher | Services/AgentLauncher.swift |
| 9 | PaneMonitor | Services/PaneMonitor.swift |
| 10 | DashboardViewModel | ViewModels/DashboardViewModel.swift |
| 11 | MenuBar + App entry | Views/MenuBarView.swift, PonyoApp.swift |
| 12 | Dashboard + TaskPool views | Views/Dashboard*.swift, TaskPool*.swift |
| 13 | PaneGrid + Drag & Drop | Views/PaneGrid*.swift, PaneCard*.swift |
| 14 | Settings + Onboarding | Views/Settings*.swift, Onboarding*.swift |
| 15 | Integration test | Tests/IntegrationTests.swift |
