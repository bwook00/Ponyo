// Sources/Views/PaneCardView.swift
import SwiftUI

struct PaneCardView: View {
    let slot: PaneSlot
    let paneIndex: Int
    let onReturn: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(slot.agent.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(slot.agent == .claudeCode ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2))
                    .cornerRadius(4)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(slot.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let issue = slot.issue {
                Text(issue.repo.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(issue.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(issue.branchName)
                    .font(.caption2)
                    .foregroundStyle(.blue)

                HStack {
                    Button(action: onReturn) {
                        Label("Return", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onComplete) {
                        Label("Done", systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                VStack {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Drop task here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(12)
        .background(.background)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusBorderColor, lineWidth: slot.isEmpty ? 1 : 2)
        )
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
