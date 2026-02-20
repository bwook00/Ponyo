// Sources/Views/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var vm: DashboardViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today: \(vm.state.todayTasks.count) tasks")
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
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Refresh Issues") {
                Task { await vm.fetchIssues() }
            }

            Divider()

            SettingsLink {
                Text("Settings...")
            }

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
