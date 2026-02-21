// Sources/PonyoApp.swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 창이 뜰 때마다 key window로 만들어서 키보드 입력 보장
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct PonyoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var vm: DashboardViewModel

    init() {
        let shell = ShellRunner()
        let tmux = TmuxService(shell: shell)
        let git = GitService(shell: shell)
        let stateStore = StateStore()
        let monitor = PaneMonitor(tmux: tmux)

        // 토큰은 state 파일에서 로드 (initialize에서 처리)
        let github = GitHubService(token: "")

        let vm = DashboardViewModel(
            tmux: tmux, git: git, github: github,
            stateStore: stateStore, monitor: monitor
        )
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some Scene {
        WindowGroup("Ponyo") {
            DashboardView(vm: vm)
        }
        .defaultSize(width: 1100, height: 650)

        Settings {
            SettingsView(vm: vm)
        }
    }
}
