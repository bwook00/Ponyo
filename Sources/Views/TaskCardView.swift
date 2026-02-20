// Sources/Views/TaskCardView.swift
import SwiftUI

struct TaskCardView: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(issue.repo.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .cornerRadius(4)
                Spacer()
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(issue.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(10)
        .background(.background)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
