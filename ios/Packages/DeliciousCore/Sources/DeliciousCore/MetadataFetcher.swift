import Foundation

public struct VideoMetadata: Equatable, Sendable {
    public var title: String?
    public var author: String?
    public var thumbnailURL: URL?
    public var videoID: String?
    public var duration: Double?

    public init(title: String? = nil, author: String? = nil, thumbnailURL: URL? = nil, videoID: String? = nil, duration: Double? = nil) {
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.videoID = videoID
        self.duration = duration
    }

    var isEmpty: Bool { title == nil && author == nil && thumbnailURL == nil && videoID == nil }
}

/// Fetches public details (title, channel, thumbnail) for a link from the site it came from.
public struct MetadataFetcher: Sendable {
    let http: any HTTPClient

    public init(http: any HTTPClient) {
        self.http = http
    }

    /// Follows a short link (t.co, vm.tiktok.com…) to where it really points.
    public func resolveRedirects(_ url: URL) async -> URL? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(Self.browserAgent, forHTTPHeaderField: "User-Agent")
        guard let result = try? await http.send(request), let final = result.1.url, final != url else { return nil }
        return final
    }

    public func fetch(for parsed: ParsedLink) async -> VideoMetadata? {
        let url = parsed.canonicalURL
        var result: VideoMetadata?
        switch parsed.provider {
        case .youtube:
            result = await oEmbed("https://www.youtube.com/oembed?format=json&url=", url)
            if let id = parsed.videoID {
                var r = result ?? VideoMetadata()
                r.thumbnailURL = URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
                result = r
            }
        case .vimeo:
            result = await oEmbed("https://vimeo.com/api/oembed.json?url=", url)
        case .tiktok:
            result = await oEmbed("https://www.tiktok.com/oembed?url=", url)
        case .dailymotion:
            result = await oEmbed("https://www.dailymotion.com/services/oembed?url=", url)
        case .loom:
            result = await oEmbed("https://www.loom.com/v1/oembed?url=", url)
        case .streamable:
            result = await oEmbed("https://api.streamable.com/oembed.json?url=", url)
        case .x:
            if let id = parsed.videoID { result = await xPost(id: id) }
            if result == nil { result = await oEmbed("https://publish.twitter.com/oembed?omit_script=1&url=", url) }
        case .instagram, .facebook, .reddit, .twitch, .web:
            break
        case .directFile:
            return nil
        }
        if result == nil || result?.isEmpty == true {
            if let og = await openGraph(url) { result = merge(result, og) }
        }
        guard let result, !result.isEmpty else { return nil }
        return result
    }

    // MARK: - oEmbed

    private struct OEmbed: Decodable {
        let title: String?
        let author_name: String?
        let thumbnail_url: String?
        let embed_product_id: String?
        let duration: Double?
    }

    func oEmbed(_ base: String, _ url: URL) async -> VideoMetadata? {
        guard let endpoint = URL(string: base + EmbedBuilder.encode(url.absoluteString)) else { return nil }
        guard let data = await get(endpoint),
              let o = try? JSONDecoder().decode(OEmbed.self, from: data) else { return nil }
        let meta = VideoMetadata(
            title: clean(o.title),
            author: clean(o.author_name),
            thumbnailURL: o.thumbnail_url.flatMap(URL.init(string:)),
            videoID: clean(o.embed_product_id),
            duration: o.duration
        )
        return meta.isEmpty ? nil : meta
    }

    // MARK: - X posts

    private struct FxResponse: Decodable {
        struct Tweet: Decodable {
            struct Author: Decodable { let name: String?; let screen_name: String? }
            struct Media: Decodable {
                struct Video: Decodable { let thumbnail_url: String?; let duration: Double? }
                struct Photo: Decodable { let url: String? }
                let videos: [Video]?
                let photos: [Photo]?
            }
            let text: String?
            let author: Author?
            let media: Media?
        }
        let tweet: Tweet?
    }

    func xPost(id: String) async -> VideoMetadata? {
        guard let endpoint = URL(string: "https://api.fxtwitter.com/status/\(id)"),
              let data = await get(endpoint),
              let tweet = (try? JSONDecoder().decode(FxResponse.self, from: data))?.tweet else { return nil }
        let firstLine = tweet.text?
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        let video = tweet.media?.videos?.first
        let thumb = video?.thumbnail_url ?? tweet.media?.photos?.first?.url
        let author = tweet.author?.name ?? tweet.author?.screen_name.map { "@\($0)" }
        let meta = VideoMetadata(
            title: clean(firstLine.map { String($0.prefix(140)) }),
            author: clean(author),
            thumbnailURL: thumb.flatMap(URL.init(string:)),
            duration: video?.duration
        )
        return meta.isEmpty ? nil : meta
    }

    // MARK: - Open Graph (any web page)

    func openGraph(_ url: URL) async -> VideoMetadata? {
        var request = URLRequest(url: url, timeoutInterval: 12)
        // Link-preview style agent: many sites only include preview tags for these.
        request.setValue("facebookexternalhit/1.1 Facebot Twitterbot/1.0", forHTTPHeaderField: "User-Agent")
        guard let result = try? await http.send(request), (200..<300).contains(result.1.statusCode) else { return nil }
        let (data, response) = result
        let html = String(decoding: data.prefix(1_000_000), as: UTF8.self)
        return Self.parseOpenGraph(html: html, baseURL: response.url ?? url)
    }

    public static func parseOpenGraph(html: String, baseURL: URL) -> VideoMetadata? {
        var tags: [String: String] = [:]
        let metaPattern = try! NSRegularExpression(pattern: "<meta\\s[^>]*>", options: [.caseInsensitive])
        let attrPattern = try! NSRegularExpression(pattern: "([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)')")
        let ns = html as NSString
        for match in metaPattern.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: match.range)
            let tns = tag as NSString
            var attrs: [String: String] = [:]
            for a in attrPattern.matches(in: tag, range: NSRange(location: 0, length: tns.length)) {
                let name = tns.substring(with: a.range(at: 1)).lowercased()
                let valueRange = a.range(at: 3).location != NSNotFound ? a.range(at: 3) : a.range(at: 4)
                attrs[name] = valueRange.location != NSNotFound ? tns.substring(with: valueRange) : ""
            }
            guard let key = (attrs["property"] ?? attrs["name"])?.lowercased(), let content = attrs["content"] else { continue }
            if tags[key] == nil { tags[key] = decodeEntities(content) }
        }
        var title = tags["og:title"] ?? tags["twitter:title"]
        if title == nil,
           let r = html.range(of: "<title[^>]*>([^<]*)</title>", options: [.regularExpression, .caseInsensitive]) {
            let raw = String(html[r]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            title = decodeEntities(raw)
        }
        let image = (tags["og:image:secure_url"] ?? tags["og:image"] ?? tags["twitter:image"])
            .flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        let author = tags["author"] ?? tags["twitter:creator"]
        let meta = VideoMetadata(title: cleanStatic(title), author: cleanStatic(author), thumbnailURL: image)
        return meta.isEmpty ? nil : meta
    }

    // MARK: - Helpers

    static let browserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let result = try? await http.send(request), (200..<300).contains(result.1.statusCode) else { return nil }
        return result.0
    }

    private func merge(_ a: VideoMetadata?, _ b: VideoMetadata) -> VideoMetadata {
        guard var a else { return b }
        a.title = a.title ?? b.title
        a.author = a.author ?? b.author
        a.thumbnailURL = a.thumbnailURL ?? b.thumbnailURL
        return a
    }

    private func clean(_ s: String?) -> String? { Self.cleanStatic(s) }

    static func cleanStatic(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    static func decodeEntities(_ s: String) -> String {
        var out = s
        let named = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        // Numeric entities like &#8217;
        while let r = out.range(of: "&#[0-9]{1,6};", options: .regularExpression) {
            let digits = out[r].dropFirst(2).dropLast()
            let replacement = UInt32(digits).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) } ?? ""
            out.replaceSubrange(r, with: replacement)
        }
        return out
    }
}
