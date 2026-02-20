// Sources/Views/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        HSplitView {
            TaskPoolView(vm: vm)
                .frame(minWidth: 250, maxWidth: 350)

            PaneGridView(vm: vm)
                .frame(minWidth: 400)
        }
        .task { await vm.onAppear() }
        .onReceive(vm.monitor.$paneInfos) { _ in
            vm.syncPaneStatuses()
        }
    }
}
