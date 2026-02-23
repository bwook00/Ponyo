// Sources/Views/PaneGridView.swift
import SwiftUI

struct PaneGridView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var showAgentPicker = false
    @State private var pendingDrop: (taskItemId: String, paneIndex: Int)?
    @State private var selectedAgent: Agent = .claudeCode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Panes", systemImage: "rectangle.split.2x2")
                    .font(.headline)
                Spacer()
                Button(action: { Task { await vm.launchTerminal() } }) {
                    Label(vm.terminalLaunched ? "Relaunch" : "Launch Terminal", systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                statusSummary
            }

            // 3열 × 2행 고정 그리드 (최대 6 panes)
            let columns = Array(repeating: GridItem(.flexible(minimum: 180), spacing: 12), count: 3)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(vm.state.paneSlots.enumerated()), id: \.element.id) { index, slot in
                        paneCard(slot: slot, index: index)
                        .dropDestination(for: String.self) { items, _ in
                            guard let taskItemId = items.first, slot.isEmpty else { return false }
                            pendingDrop = (taskItemId, index)
                            showAgentPicker = true
                            return true
                        }
                    }

                    if vm.state.paneSlots.count < DashboardViewModel.maxPanes {
                        Button(action: { Task { await vm.addPane() } }) {
                            VStack {
                                Image(systemName: "plus.rectangle")
                                    .font(.title2)
                                Text("Add Pane")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
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
        }
        .padding()
        .sheet(isPresented: $showAgentPicker) {
            AgentPickerSheet(
                selectedAgent: $selectedAgent,
                onLaunch: {
                    guard let drop = pendingDrop,
                          let taskItem = vm.state.todayTasks.first(where: { $0.id == drop.taskItemId })
                    else { return }
                    Task { await vm.assignTask(taskItem, toPaneAt: drop.paneIndex, agent: selectedAgent) }
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

    private static let gridColumns = 3

    private func paneCard(slot: PaneSlot, index: Int) -> PaneCardView {
        let count = vm.state.paneSlots.count
        let cols = Self.gridColumns
        let hasLeft = index % cols > 0
        let hasRight = index % cols < cols - 1 && index + 1 < count
        let hasUp = index >= cols
        let hasDown = index + cols < count

        return PaneCardView(
            slot: slot,
            paneIndex: index,
            onReturn: { Task { await vm.returnToToday(paneIndex: index) } },
            onComplete: { Task { await vm.completeTask(paneIndex: index) } },
            onRestart: slot.taskItem != nil ? { Task { await vm.restartAgent(paneIndex: index) } } : nil,
            onDelete: { Task { await vm.removePane(at: index) } },
            onMoveLeft: hasLeft ? { Task { await vm.movePane(from: index, to: index - 1) } } : nil,
            onMoveRight: hasRight ? { Task { await vm.movePane(from: index, to: index + 1) } } : nil,
            onMoveUp: hasUp ? { Task { await vm.movePane(from: index, to: index - cols) } } : nil,
            onMoveDown: hasDown ? { Task { await vm.movePane(from: index, to: index + cols) } } : nil
        )
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
