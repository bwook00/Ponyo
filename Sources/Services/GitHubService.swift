// Sources/Services/GitHubService.swift
import Foundation

actor GitHubService {
    private let token: String
    private let urlSession: URLSession
    private let baseURL = "https://api.github.com"

    init(token: String, urlSession: URLSession = .shared) {
        self.token = token
        self.urlSession = urlSession
    }

    func fetchIssues(repo: RepoConfig) async throws -> [Issue] {
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues?state=open&per_page=100")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await urlSession.data(for: request)
        let decoded = try JSONDecoder().decode([GitHubIssue].self, from: data)

        return decoded.map { gh in
            Issue(
                number: gh.number,
                title: gh.title,
                body: gh.body ?? "",
                labels: gh.labels.map(\.name),
                repo: repo
            )
        }
    }

    func addLabel(repo: RepoConfig, issueNumber: Int, label: String) async throws {
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues/\(issueNumber)/labels")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["labels": [label]])
        _ = try await urlSession.data(for: request)
    }

    func removeLabel(repo: RepoConfig, issueNumber: Int, label: String) async throws {
        let encoded = label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? label
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues/\(issueNumber)/labels/\(encoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await urlSession.data(for: request)
    }
}

// GitHub API response types (internal)
private struct GitHubIssue: Decodable {
    let number: Int
    let title: String
    let body: String?
    let labels: [GitHubLabel]
}

private struct GitHubLabel: Decodable {
    let name: String
}
