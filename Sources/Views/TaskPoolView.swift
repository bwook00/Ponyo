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
                                .draggable(issue.id)
                        }
                    }
                }
            }

            Divider()

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
