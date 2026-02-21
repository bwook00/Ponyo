// Sources/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var token: String = ""
    @State private var showToken = false

    var body: some View {
        Form {
            Section("GitHub Token") {
                HStack(spacing: 8) {
                    if showToken {
                        TextField("Personal Access Token", text: $token)
                    } else {
                        SecureField("Personal Access Token", text: $token)
                    }
                    Button(action: { showToken.toggle() }) {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Button("Save Token") {
                        vm.state.githubToken = token
                        vm.refreshGitHubToken()
                    }
                    Spacer()
                    Button("Generate Token on GitHub") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Ponyo")!)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }

            if !vm.state.githubUsername.isEmpty {
                Section("GitHub") {
                    HStack {
                        Text("Logged in as")
                            .foregroundStyle(.secondary)
                        Text("@\(vm.state.githubUsername)")
                            .fontWeight(.medium)
                    }
                }
            }

            Section("Repositories") {
                if vm.state.repos.isEmpty {
                    Text("No repos added. Use the + button in the dashboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.state.repos) { repo in
                    HStack {
                        Text(repo.id)
                        Spacer()
                        Text(repo.localPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            Task { await vm.removeRepo(repo) }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .onAppear {
            token = vm.state.githubToken
        }
    }
}
