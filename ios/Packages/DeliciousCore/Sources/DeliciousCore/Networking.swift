import Foundation

/// Minimal HTTP abstraction so the network can be faked in tests.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

// MARK: - Tidy (title + tags from our server)

public struct TidyResult: Equatable, Sendable, Decodable {
    public let title: String
    public let tags: [String]

    public init(title: String, tags: [String]) {
        self.title = title
        self.tags = tags
    }
}

/// Asks the delicious server for a clean title and a few tags.
/// Any failure (no server configured, offline, slow, bad reply) quietly returns nil.
public struct TidyClient: Sendable {
    public let endpoint: URL?
    let http: any HTTPClient

    public init(endpoint: URL?, http: any HTTPClient) {
        self.endpoint = endpoint
        self.http = http
    }

    public func tidy(url: URL, title: String?, author: String?, provider: String) async -> TidyResult? {
        guard let endpoint else { return nil }
        var payload: [String: String] = ["url": url.absoluteString, "provider": provider]
        if let title { payload["title"] = title }
        if let author { payload["author"] = author }
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ios", forHTTPHeaderField: "X-Delicious-Client")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await http.send(request)
            guard response.statusCode == 200 else { return nil }
            let raw = try JSONDecoder().decode(TidyResult.self, from: data)
            let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let tags = raw.tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            var unique: [String] = []
            for tag in tags where !unique.contains(tag) { unique.append(tag) }
            return TidyResult(title: String(title.prefix(80)), tags: Array(unique.prefix(3)))
        } catch {
            return nil
        }
    }
}
