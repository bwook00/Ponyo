// Sources/Views/PaneCardView.swift
import SwiftUI

struct PaneCardView: View {
    let slot: PaneSlot
    let paneIndex: Int
    let onReturn: () -> Void
    let onComplete: () -> Void
    var onRestart: (() -> Void)?
    let onDelete: () -> Void
    var onMoveLeft: (() -> Void)?
    var onMoveRight: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    private var paneLabel: String {
        "Ponyo \(paneIndex + 1)"
    }

    private var taskSummary: String? {
        guard let taskItem = slot.taskItem else { return nil }
        if taskItem.isManual {
            return taskItem.displayName
        }
        if let issue = taskItem.issues.first {
            return "\(issue.repo.name)-#\(issue.number) \(issue.title)"
        }
        return taskItem.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                // Pane label
                Text(paneLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(slot.isEmpty ? Color.secondary : agentColor)
                    .cornerRadius(6)

                // Move arrows
                moveButtons

                if slot.taskItem != nil {
                    Text(slot.agent.displayName)
                        .font(.caption2)
                        .foregroundStyle(agentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(agentColor.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                if slot.isEmpty {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove Pane")
                }
            }

            if let summary = taskSummary {
                // Task title — "Ponyo-#10 Add Notification for agent completion"
                Text(summary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                // Group 이슈 목록
                if let taskItem = slot.taskItem, taskItem.isGroup {
                    ForEach(taskItem.issues.dropFirst()) { issue in
                        Text("\(issue.repo.name)-#\(issue.number) \(issue.title)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Action buttons
                HStack(spacing: 6) {
                    if let onRestart {
                        Button(action: onRestart) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Restart Agent")
                    }

                    Button(action: onReturn) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Return to Today")

                    Button(action: onComplete) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.green)
                    .help("Complete")

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove Pane")
                }
            } else {
                VStack {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Drop task here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
        }
        .padding(10)
        .background(.background)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusBorderColor, lineWidth: slot.isEmpty ? 1 : 2)
        )
    }

    @ViewBuilder
    private var moveButtons: some View {
        HStack(spacing: 2) {
            if let onMoveLeft {
                Button(action: onMoveLeft) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move Left")
            }
            if let onMoveUp {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move Up")
            }
            if let onMoveDown {
                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move Down")
            }
            if let onMoveRight {
                Button(action: onMoveRight) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Move Right")
            }
        }
    }

    private var agentColor: Color {
        slot.agent == .claudeCode ? .orange : .blue
    }

    private var statusColor: Color {
        switch slot.status {
        case .running: .green
        case .idle: .yellow
        case .crashed: .red
        }
    }

    private var statusBorderColor: Color {
        slot.isEmpty ? Color.secondary.opacity(0.3) : statusColor.opacity(0.5)
    }
}
