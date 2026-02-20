// Sources/Views/TaskPoolView.swift
import SwiftUI

struct RepoListView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var showAddRepo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Repositories", systemImage: "folder.fill")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await vm.fetchIssues() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(vm.isLoading)
                .help("Refresh all issues")
                Button(action: { showAddRepo = true }) {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .help("Add repository")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if vm.state.repos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No repositories")
                        .font(.subheadline)
                    Button("Add Repository") { showAddRepo = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Repo list with expandable issues
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.state.repos) { repo in
                            RepoRow(vm: vm, repo: repo)
                        }
                    }
                }
            }

            if vm.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading issues...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
        .sheet(isPresented: $showAddRepo) {
            AddRepoSheet(vm: vm, isPresented: $showAddRepo)
        }
    }
}

// MARK: - Repo Row (expandable)

struct RepoRow: View {
    @ObservedObject var vm: DashboardViewModel
    let repo: RepoConfig
    @State private var isExpanded = true

    private var issues: [Issue] {
        vm.issuesForRepo(repo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Repo header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text(repo.id)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer()

                    Text("\(issues.count)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(issues.isEmpty ? Color.secondary : Color.blue)
                        .cornerRadius(8)

                    // Context menu for repo actions
                    Menu {
                        Button("Refresh Issues") {
                            Task { await vm.fetchIssuesForRepo(repo) }
                        }
                        Divider()
                        Button("Remove", role: .destructive) {
                            Task { await vm.removeRepo(repo) }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Issues list (expanded)
            if isExpanded {
                if issues.isEmpty {
                    Text("No open issues")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 36)
                        .padding(.vertical, 4)
                } else {
                    ForEach(issues) { issue in
                        IssueRow(issue: issue, onPick: { vm.pickForToday(issue) })
                            .padding(.leading, 24)
                            .padding(.trailing, 8)
                            .padding(.vertical, 2)
                    }
                }
            }

            Divider()
        }
    }
}

// MARK: - Issue Row

struct IssueRow: View {
    let issue: Issue
    let onPick: () -> Void
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dotted")
                .foregroundStyle(.green)
                .font(.caption)

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if !issue.labels.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(issue.labels.prefix(3), id: \.self) { label in
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

            Spacer()

            Button(action: onPick) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .help("Add to Today's Tasks")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.background)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { showDetail.toggle() }
        .popover(isPresented: $showDetail, arrowEdge: .trailing) {
            IssueDetailPopover(issue: issue)
        }
    }
}

struct IssueDetailPopover: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(issue.repo.id)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Text(issue.title)
                .font(.headline)

            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Divider()

            if issue.body.isEmpty {
                Text("No description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ScrollView {
                    Text(issue.body)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

// MARK: - Add Repo Sheet

struct AddRepoSheet: View {
    @ObservedObject var vm: DashboardViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var addingRepoId: String?

    private var filteredRepos: [GitHubRepoInfo] {
        let already = Set(vm.state.repos.map(\.id))
        let available = vm.availableRepos.filter { !already.contains($0.fullName) }
        if searchText.isEmpty { return available }
        return available.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Repository")
                    .font(.headline)
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            TextField("Search repos...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            if vm.isLoadingRepos {
                VStack {
                    ProgressView()
                    Text("Fetching your repositories...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.availableRepos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No repos found")
                        .font(.subheadline)
                    Text("Check your GitHub token has repo scope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredRepos) { repo in
                    RepoPickerRow(repo: repo, isAdding: addingRepoId == repo.id) {
                        addRepo(repo)
                    }
                }
            }
        }
        .frame(width: 480, height: 420)
        .task {
            if vm.availableRepos.isEmpty {
                await vm.fetchAvailableRepos()
            }
        }
    }

    private func addRepo(_ repo: GitHubRepoInfo) {
        addingRepoId = repo.id
        Task {
            // 1. 로컬에서 자동 탐색
            if let localPath = await vm.findLocalClone(for: repo) {
                await vm.addRepo(repo, localPath: localPath)
                addingRepoId = nil
                return
            }
            // 2. 못 찾으면 폴더 선택 다이얼로그
            await MainActor.run {
                let panel = NSOpenPanel()
                panel.title = "\(repo.name) clone folder"
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.message = "Could not auto-detect. Select the local clone of \(repo.fullName)"

                if panel.runModal() == .OK, let url = panel.url {
                    Task { await vm.addRepo(repo, localPath: url.path) }
                }
                addingRepoId = nil
            }
        }
    }
}

struct RepoPickerRow: View {
    let repo: GitHubRepoInfo
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: repo.isPrivate ? "lock.fill" : "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(repo.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                if let desc = repo.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isAdding {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Add") { onAdd() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 2)
    }
}
