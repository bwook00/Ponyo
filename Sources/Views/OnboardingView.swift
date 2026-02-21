// Sources/Views/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var token = ""
    @State private var showToken = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "fish.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Welcome to Ponyo")
                .font(.title)
                .fontWeight(.bold)

            Text("Enter your GitHub Personal Access Token to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Generate Token on GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Ponyo")!)
            }
            .buttonStyle(.link)
            .font(.caption)

            HStack(spacing: 8) {
                if showToken {
                    TextField("ghp_...", text: $token)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("ghp_...", text: $token)
                        .textFieldStyle(.roundedBorder)
                }
                Button(action: { showToken.toggle() }) {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)

            Button("Get Started") {
                vm.state.githubToken = token
                vm.refreshGitHubToken()
                Task { await vm.initialize() }
            }
            .disabled(token.isEmpty)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
