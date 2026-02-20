// Sources/Views/PaneGridView.swift
import SwiftUI

struct PaneGridView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        Text("Pane Grid")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
