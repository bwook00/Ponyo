// Sources/Models/RepoConfig.swift
import Foundation

struct RepoConfig: Codable, Identifiable, Hashable {
    var id: String { "\(owner)/\(name)" }
    let owner: String
    let name: String
    let localPath: String
}
