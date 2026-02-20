// Sources/Views/TodayTasksView.swift
import SwiftUI

struct TodayTasksView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var selectedIds: Set<String> = []
    @State private var showGroupSheet = false
    @State private var groupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Today's Tasks", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                if selectedIds.count >= 2 {
                    Button(action: { showGroupSheet = true }) {
                        Label("Group", systemImage: "rectangle.stack")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Text("\(vm.state.todayTasks.count)")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if vm.state.todayTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No tasks for today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Click issues from repos to add")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(vm.state.todayTasks) { item in
                            TodayTaskCard(
                                item: item,
                                isSelected: selectedIds.contains(item.id),
                                onToggleSelect: { toggleSelection(item.id) },
                                onRemove: { vm.removeFromToday(item) },
                                onUngroup: item.isGroup ? { vm.ungroupTask(item) } : nil
                            )
                            .draggable(item.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .sheet(isPresented: $showGroupSheet) {
            GroupNameSheet(
                groupName: $groupName,
                issueCount: selectedIds.count,
                onCreate: {
                    vm.groupTasks(selectedIds, name: groupName)
                    selectedIds.removeAll()
                    groupName = ""
                    showGroupSheet = false
                },
                onCancel: { showGroupSheet = false }
            )
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

// MARK: - Today Task Card

struct TodayTaskCard: View {
    let item: TaskItem
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onRemove: () -> Void
    var onUngroup: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Selection checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if item.isGroup {
                    // Group header
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(item.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("(\(item.issues.count))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Group issues
                    ForEach(item.issues) { issue in
                        HStack(spacing: 4) {
                            Text("  \(issue.displayTitle)")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                } else if let issue = item.issues.first {
                    // Single issue
                    HStack(spacing: 4) {
                        Text(issue.repo.name)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15))
                            .cornerRadius(3)
                        Spacer()
                        Text("#\(issue.number)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(issue.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 4) {
                if let onUngroup {
                    Button(action: onUngroup) {
                        Image(systemName: "rectangle.stack.badge.minus")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                    .help("Ungroup")
                }
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove from today")
            }

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Group Name Sheet

struct GroupNameSheet: View {
    @Binding var groupName: String
    let issueCount: Int
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Group")
                .font(.headline)
            Text("\(issueCount) tasks will be grouped together")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Group name (e.g. Auth, Refactor)", text: $groupName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create Group", action: onCreate)
                    .disabled(groupName.isEmpty)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}
