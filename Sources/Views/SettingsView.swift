// Sources/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        Text("Settings")
            .frame(width: 400, height: 300)
    }
}
