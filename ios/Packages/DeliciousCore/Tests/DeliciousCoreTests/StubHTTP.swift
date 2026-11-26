import Foundation
@testable import DeliciousCore

/// Fake network: answers requests by matching the start of the URL.
final class StubHTTP: HTTPClient, @unchecked Sendable {
    struct Reply {
        var status: Int = 200
        var body: Data = Data()
        var finalURL: URL?
    }

    private let lock = NSLock()
    private var routes: [(prefix: String, reply: Reply)] = []
    private(set) var requests: [URLRequest] = []
    var failAll = false

    func on(_ prefix: String, status: Int = 200, json: String = "", finalURL: URL? = nil) {
        lock.lock(); defer { lock.unlock() }
        routes.append((prefix, Reply(status: status, body: Data(json.utf8), finalURL: finalURL)))
    }

    func on(_ prefix: String, html: String) {
        on(prefix, json: html)
    }

    var requestedURLs: [String] {
        lock.lock(); defer { lock.unlock() }
        return requests.compactMap { $0.url?.absoluteString }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock()
        requests.append(request)
        let url = request.url!
        let match = routes.first { url.absoluteString.hasPrefix($0.prefix) }
        let fail = failAll
        lock.unlock()
        if fail { throw URLError(.notConnectedToInternet) }
        guard let match else {
            return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }
        let response = HTTPURLResponse(url: match.reply.finalURL ?? url, statusCode: match.reply.status, httpVersion: nil, headerFields: nil)!
        return (match.reply.body, response)
    }
}
