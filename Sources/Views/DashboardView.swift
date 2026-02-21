// Sources/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        Group {
            if !vm.isInitialized {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.state.githubToken.isEmpty {
                OnboardingView(vm: vm)
            } else {
                VSplitView {
                    HSplitView {
                        RepoListView(vm: vm)
                            .frame(minWidth: 200, maxWidth: 260)

                        TodayTasksView(vm: vm)
                            .frame(minWidth: 200)
                    }
                    .frame(minHeight: 220)

                    PaneGridView(vm: vm)
                        .frame(minHeight: 200)
                }
                .onReceive(vm.monitor.$paneInfos) { _ in
                    vm.syncPaneStatuses()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            NSApp.activate(ignoringOtherApps: true)
            await vm.initialize()
        }
    }
}
