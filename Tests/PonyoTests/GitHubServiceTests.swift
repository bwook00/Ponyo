// Tests/PonyoTests/GitHubServiceTests.swift
import Testing
import Foundation
@testable import Ponyo

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!.absoluteString
        if let (data, response) = Self.mockResponses[url] {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct GitHubServiceTests {
    @Test func fetchIssues() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = GitHubService(token: "fake-token", urlSession: session)

        let issuesJSON = """
        [{"number": 42, "title": "Add auth", "body": "Details", "labels": [{"name": "enhancement"}]},
         {"number": 15, "title": "Fix bug", "body": null, "labels": []}]
        """
        let url = "https://api.github.com/repos/user/repo-A/issues?state=open&per_page=100"
        MockURLProtocol.mockResponses[url] = (
            issuesJSON.data(using: .utf8)!,
            HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        let repo = RepoConfig(owner: "user", name: "repo-A", localPath: "/tmp")
        let issues = try await service.fetchIssues(repo: repo)

        #expect(issues.count == 2)
        #expect(issues[0].number == 42)
        #expect(issues[0].title == "Add auth")
        #expect(issues[0].labels == ["enhancement"])
        #expect(issues[1].body == "")  // null body should become empty string
    }
}
