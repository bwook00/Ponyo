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

    /// 내가 접근 가능한 모든 레포 목록
    func fetchUserRepos() async throws -> [GitHubRepoInfo] {
        var allRepos: [GitHubRepoInfo] = []
        var page = 1
        while true {
            let url = URL(string: "\(baseURL)/user/repos?per_page=100&sort=updated&page=\(page)")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await urlSession.data(for: request)
            let decoded = try JSONDecoder().decode([GitHubRepoRaw].self, from: data)
            if decoded.isEmpty { break }
            allRepos.append(contentsOf: decoded.map { raw in
                GitHubRepoInfo(
                    fullName: raw.full_name,
                    owner: raw.owner.login,
                    name: raw.name,
                    isPrivate: raw.isPrivate,
                    description: raw.description
                )
            })
            if decoded.count < 100 { break }
            page += 1
        }
        return allRepos
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

    /// 현재 인증된 유저의 login 이름
    func fetchCurrentUser() async throws -> String {
        let url = URL(string: "\(baseURL)/user")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await urlSession.data(for: request)
        let user = try JSONDecoder().decode(GitHubUser.self, from: data)
        return user.login
    }

    /// 이슈에 나를 assign
    func assignIssue(repo: RepoConfig, issueNumber: Int, assignee: String) async throws {
        let url = URL(string: "\(baseURL)/repos/\(repo.owner)/\(repo.name)/issues/\(issueNumber)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: [String]] = ["assignees": [assignee]]
        request.httpBody = try JSONEncoder().encode(body)
        _ = try await urlSession.data(for: request)
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

// MARK: - Public API types

struct GitHubRepoInfo: Identifiable, Hashable {
    var id: String { fullName }
    let fullName: String   // "owner/name"
    let owner: String
    let name: String
    let isPrivate: Bool
    let description: String?
}

// MARK: - GitHub API response types (internal)

private struct GitHubRepoRaw: Decodable {
    let full_name: String
    let name: String
    let owner: GitHubOwner
    let isPrivate: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case full_name, name, owner, description
        case isPrivate = "private"
    }
}

private struct GitHubOwner: Decodable {
    let login: String
}

private struct GitHubUser: Decodable {
    let login: String
}

private struct GitHubIssue: Decodable {
    let number: Int
    let title: String
    let body: String?
    let labels: [GitHubLabel]
}

private struct GitHubLabel: Decodable {
    let name: String
}
