// Sources/Models/ManualTask.swift
import Foundation

struct ManualTask: Codable, Identifiable, Hashable {
    var id: String { identifier }
    let identifier: String
    let title: String
    let description: String
    let workingDirectory: String?

    init(title: String, description: String = "", workingDirectory: String? = nil) {
        self.identifier = UUID().uuidString
        self.title = title
        self.description = description
        self.workingDirectory = workingDirectory
    }
}
