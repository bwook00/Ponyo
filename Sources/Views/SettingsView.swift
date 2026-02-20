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
