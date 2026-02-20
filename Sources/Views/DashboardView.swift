// Sources/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(vm: vm, isPresented: $showOnboarding)
            } else {
                HSplitView {
                    RepoListView(vm: vm)
                        .frame(minWidth: 220, maxWidth: 300)

                    TodayTasksView(vm: vm)
                        .frame(minWidth: 220, maxWidth: 320)

                    PaneGridView(vm: vm)
                        .frame(minWidth: 400)
                }
                .onReceive(vm.monitor.$paneInfos) { _ in
                    vm.syncPaneStatuses()
                }
            }
        }
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            }
            let hasToken = KeychainHelper.load(key: "github-token") != nil
            if !hasToken {
                showOnboarding = true
            }
        }
    }
}
