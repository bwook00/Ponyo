// Sources/PonyoApp.swift
import SwiftUI

@main
struct PonyoApp: App {
    var body: some Scene {
        MenuBarExtra("Ponyo", systemImage: "fish") {
            Text("Ponyo is running")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
