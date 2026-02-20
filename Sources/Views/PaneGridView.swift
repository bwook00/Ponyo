// Sources/Views/PaneGridView.swift
import SwiftUI

struct PaneGridView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var showAgentPicker = false
    @State private var pendingDrop: (issueId: String, paneIndex: Int)?
    @State private var selectedAgent: Agent = .claudeCode

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Panes", systemImage: "rectangle.split.2x2")
                    .font(.headline)
                Spacer()
                statusSummary
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(vm.state.paneSlots.enumerated()), id: \.element.id) { index, slot in
                        PaneCardView(
                            slot: slot,
                            paneIndex: index,
                            onReturn: { Task { await vm.returnToPool(paneIndex: index) } },
                            onComplete: { Task { await vm.completeTask(paneIndex: index) } }
                        )
                        .dropDestination(for: String.self) { items, _ in
                            guard let issueId = items.first, slot.isEmpty else { return false }
                            pendingDrop = (issueId, index)
                            showAgentPicker = true
                            return true
                        }
                    }

                    Button(action: { Task { await vm.addPane() } }) {
                        VStack {
                            Image(systemName: "plus.rectangle")
                                .font(.title)
                            Text("Add Pane")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(.secondary.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showAgentPicker) {
            AgentPickerSheet(
                selectedAgent: $selectedAgent,
                onLaunch: {
                    guard let drop = pendingDrop,
                          let issue = vm.state.taskPool.first(where: { $0.id == drop.issueId })
                    else { return }
                    Task { await vm.assignIssue(issue, toPaneAt: drop.paneIndex, agent: selectedAgent) }
                    showAgentPicker = false
                    pendingDrop = nil
                },
                onCancel: {
                    showAgentPicker = false
                    pendingDrop = nil
                }
            )
        }
    }

    private var statusSummary: some View {
        HStack(spacing: 12) {
            let running = vm.state.paneSlots.filter { $0.status == .running }.count
            let idle = vm.state.paneSlots.filter { $0.status == .idle }.count
            Label("\(running)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Label("\(idle)", systemImage: "circle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        }
    }
}

struct AgentPickerSheet: View {
    @Binding var selectedAgent: Agent
    let onLaunch: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Which agent?")
                .font(.headline)

            Picker("Agent", selection: $selectedAgent) {
                ForEach(Agent.allCases, id: \.self) { agent in
                    Text(agent.displayName).tag(agent)
                }
            }
            .pickerStyle(.radioGroup)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Launch", action: onLaunch)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 250)
    }
}
