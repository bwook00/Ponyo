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

        Settings {
            SettingsView(vm: vm)
        }
    }
}
