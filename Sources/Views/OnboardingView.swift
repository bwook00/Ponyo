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
