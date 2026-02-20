// Sources/Services/PaneMonitor.swift
import Foundation
import Combine

@MainActor
final class PaneMonitor: ObservableObject {
    @Published var paneInfos: [TmuxPaneInfo] = []
    private let tmux: TmuxService
    private var timer: Timer?

    init(tmux: TmuxService) {
        self.tmux = tmux
    }

    func start(interval: TimeInterval = 2.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() async {
        do {
            paneInfos = try await tmux.listPanes()
        } catch {
            paneInfos = []
        }
    }

    /// pane_current_command로 Agent 상태 판별
    func agentStatus(for paneId: String) -> PaneStatus {
        guard let info = paneInfos.first(where: { $0.id == paneId }) else {
            return .idle
        }
        let agentCommands = Set(Agent.allCases.map(\.command))
        if agentCommands.contains(info.command) {
            return .running
        }
        return .idle
    }
}
