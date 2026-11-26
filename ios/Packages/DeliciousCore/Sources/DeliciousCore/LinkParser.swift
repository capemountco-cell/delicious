import Foundation

public struct ParsedLink: Equatable, Sendable {
    public var provider: Provider
    public var videoID: String?
    public var canonicalURL: URL
    public var aspect: VideoAspect
    public var startSeconds: Int?

    public init(provider: Provider, videoID: String?, canonicalURL: URL, aspect: VideoAspect = .landscape, startSeconds: Int? = nil) {
        self.provider = provider
        self.videoID = videoID
        self.canonicalURL = canonicalURL
        self.aspect = aspect
        self.startSeconds = startSeconds
    }
}

/// Recognises video links from popular sites and pulls out what we need to play them inline.
public enum LinkParser {
    // MARK: - Finding a link in pasted text

    /// Finds the first web link in any pasted text ("check this out https://…").
    public static func extractURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        for match in detector.matches(in: trimmed, options: [], range: range) {
            guard let url = match.url, let scheme = url.scheme?.lowercased() else { continue }
            guard scheme == "http" || scheme == "https", url.host != nil else { continue }
            return url
        }
        return nil
    }

    // MARK: - Short links

    private static let shortenerHosts: Set<String> = [
        "t.co", "bit.ly", "tinyurl.com", "vm.tiktok.com", "vt.tiktok.com", "fb.watch",
        "v.redd.it", "redd.it", "goo.gl", "ow.ly", "buff.ly", "dlvr.it", "lnkd.in", "is.gd", "youtube.app.goo.gl",
    ]

    /// Short links (t.co, vm.tiktok.com…) must be followed before we know what they point to.
    public static func needsRedirectResolution(_ url: URL) -> Bool {
        let h = host(url)
        let parts = pathParts(url)
        if shortenerHosts.contains(h) { return true }
        if h == "tiktok.com", parts.first == "t" { return true }
        if h == "facebook.com", parts.first == "share" { return true }
        if h.hasSuffix("reddit.com"), parts.count >= 3, parts[2] == "s" { return true }
        return false
    }

    // MARK: - Parsing

    public static func parse(_ url: URL) -> ParsedLink {
        let h = host(url)
        let parts = pathParts(url)

        // YouTube
        if h == "youtu.be", let id = parts.first, isYouTubeID(id) {
            return youtube(id: id, shorts: false, from: url)
        }
        if h == "youtube.com" || h == "youtube-nocookie.com" {
            if let v = query(url, "v"), isYouTubeID(v) {
                return youtube(id: v, shorts: false, from: url)
            }
            if parts.count >= 2, ["shorts", "embed", "live", "v", "e"].contains(parts[0]), isYouTubeID(parts[1]) {
                return youtube(id: parts[1], shorts: parts[0] == "shorts", from: url)
            }
        }

        // X / Twitter
        if ["x.com", "twitter.com", "fxtwitter.com", "vxtwitter.com", "fixupx.com", "fixvx.com"].contains(h),
           let i = parts.firstIndex(where: { $0 == "status" || $0 == "statuses" }),
           i + 1 < parts.count, isDigits(parts[i + 1]) {
            let id = parts[i + 1]
            let user = (i > 0 && parts[0] != "i") ? parts[0] : "i"
            return ParsedLink(provider: .x, videoID: id, canonicalURL: URL(string: "https://x.com/\(user)/status/\(id)")!)
        }

        // TikTok
        if h == "tiktok.com" || h.hasSuffix(".tiktok.com") {
            var id: String?
            if let i = parts.firstIndex(of: "video"), i + 1 < parts.count, isDigits(parts[i + 1]) {
                id = parts[i + 1]
            } else if parts.count >= 3, parts[0] == "embed", parts[1] == "v2", isDigits(parts[2]) {
                id = parts[2]
            } else if parts.count >= 3, parts[0] == "player", parts[1] == "v1", isDigits(parts[2]) {
                id = parts[2]
            } else if parts.count >= 2, parts[0] == "v" {
                let candidate = parts[1].replacingOccurrences(of: ".html", with: "")
                if isDigits(candidate) { id = candidate }
            }
            var canonical = url
            if let id {
                let user = parts.first(where: { $0.hasPrefix("@") && $0.count > 1 })
                if let user { canonical = URL(string: "https://www.tiktok.com/\(user)/video/\(id)")! }
            }
            return ParsedLink(provider: .tiktok, videoID: id, canonicalURL: canonical, aspect: .portrait)
        }

        // Instagram
        if h == "instagram.com" || h == "instagr.am" {
            for (i, part) in parts.enumerated() where ["p", "reel", "reels", "tv"].contains(part) && i + 1 < parts.count {
                let kind = part == "p" ? "p" : (part == "tv" ? "tv" : "reel")
                let code = parts[i + 1]
                return ParsedLink(
                    provider: .instagram,
                    videoID: "\(kind)/\(code)",
                    canonicalURL: URL(string: "https://www.instagram.com/\(kind)/\(code)/")!,
                    aspect: kind == "p" ? .square : .portrait
                )
            }
            return ParsedLink(provider: .instagram, videoID: nil, canonicalURL: url, aspect: .portrait)
        }

        // Vimeo
        if h == "vimeo.com" || h == "player.vimeo.com" {
            if let idx = parts.firstIndex(where: { isDigits($0) && $0.count >= 5 }) {
                let id = parts[idx]
                var hash: String? = query(url, "h")
                if idx + 1 < parts.count, isHex(parts[idx + 1]) { hash = parts[idx + 1] }
                let videoID = hash.map { "\(id)/\($0)" } ?? id
                let canonical = URL(string: "https://vimeo.com/\(id)" + (hash.map { "/\($0)" } ?? ""))!
                return ParsedLink(provider: .vimeo, videoID: videoID, canonicalURL: canonical)
            }
        }

        // Facebook
        if ["facebook.com", "fb.com", "web.facebook.com", "fb.watch"].contains(h) {
            let vertical = parts.contains("reel") || parts.contains("reels") || (parts.first == "share" && parts.dropFirst().first == "r")
            return ParsedLink(provider: .facebook, videoID: nil, canonicalURL: url, aspect: vertical ? .portrait : .landscape)
        }

        // Dailymotion
        if h == "dailymotion.com" {
            var raw: String?
            if parts.count >= 2, parts[0] == "video" { raw = parts[1] }
            if parts.count >= 3, parts[0] == "embed", parts[1] == "video" { raw = parts[2] }
            if let raw, let id = raw.split(separator: "_").first.map(String.init), !id.isEmpty {
                return ParsedLink(provider: .dailymotion, videoID: id, canonicalURL: URL(string: "https://www.dailymotion.com/video/\(id)")!)
            }
        }
        if h == "dai.ly", let id = parts.first {
            return ParsedLink(provider: .dailymotion, videoID: id, canonicalURL: URL(string: "https://www.dailymotion.com/video/\(id)")!)
        }

        // Loom
        if h == "loom.com", parts.count >= 2, ["share", "embed"].contains(parts[0]) {
            let id = parts[1]
            return ParsedLink(provider: .loom, videoID: id, canonicalURL: URL(string: "https://www.loom.com/share/\(id)")!)
        }

        // Streamable
        if h == "streamable.com" {
            var id: String?
            if parts.count >= 2, ["e", "o", "s"].contains(parts[0]) { id = parts[1] } else if parts.count == 1 { id = parts[0] }
            if let id, id.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return ParsedLink(provider: .streamable, videoID: id, canonicalURL: URL(string: "https://streamable.com/\(id)")!)
            }
        }

        // Reddit
        if h == "reddit.com" || h.hasSuffix(".reddit.com") {
            var id: String?
            if let i = parts.firstIndex(of: "comments"), i + 1 < parts.count { id = parts[i + 1] }
            return ParsedLink(provider: .reddit, videoID: id, canonicalURL: url)
        }

        // Twitch
        if h == "clips.twitch.tv", let slug = parts.first, slug != "embed" {
            return ParsedLink(provider: .twitch, videoID: "clip:\(slug)", canonicalURL: url)
        }
        if h == "twitch.tv" {
            if let i = parts.firstIndex(of: "clip"), i + 1 < parts.count {
                return ParsedLink(provider: .twitch, videoID: "clip:\(parts[i + 1])", canonicalURL: url)
            }
            if parts.count >= 2, parts[0] == "videos", isDigits(parts[1]) {
                return ParsedLink(provider: .twitch, videoID: "video:\(parts[1])", canonicalURL: url)
            }
            if parts.count == 1 {
                return ParsedLink(provider: .twitch, videoID: "channel:\(parts[0])", canonicalURL: url)
            }
        }

        // Direct video files
        if ["mp4", "m4v", "mov", "m3u8"].contains(url.pathExtension.lowercased()) {
            return ParsedLink(provider: .directFile, videoID: nil, canonicalURL: url)
        }

        return ParsedLink(provider: .web, videoID: nil, canonicalURL: url)
    }

    // MARK: - Helpers

    static func host(_ url: URL) -> String {
        var h = (url.host ?? "").lowercased()
        for prefix in ["www.", "m.", "mobile.", "music."] where h.hasPrefix(prefix) {
            h.removeFirst(prefix.count)
        }
        return h
    }

    static func pathParts(_ url: URL) -> [String] {
        url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
    }

    static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == name })?.value
    }

    static func isDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber }
    }

    static func isHex(_ s: String) -> Bool {
        s.count >= 6 && s.allSatisfy { $0.isHexDigit }
    }

    static func isYouTubeID(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "-" || $0 == "_" }
    }

    /// "90", "90s", "1m30s", "1h2m3s" → seconds.
    static func parseTime(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        if let plain = Int(raw) { return plain > 0 ? plain : nil }
        var total = 0
        var number = ""
        for ch in raw.lowercased() {
            if ch.isNumber {
                number.append(ch)
            } else {
                guard let n = Int(number) else { return nil }
                switch ch {
                case "h": total += n * 3600
                case "m": total += n * 60
                case "s": total += n
                default: return nil
                }
                number = ""
            }
        }
        if !number.isEmpty, let n = Int(number) { total += n }
        return total > 0 ? total : nil
    }

    private static func youtube(id: String, shorts: Bool, from url: URL) -> ParsedLink {
        let start = parseTime(query(url, "t") ?? query(url, "start"))
        let canonical: String
        if shorts {
            canonical = "https://www.youtube.com/shorts/\(id)"
        } else {
            canonical = "https://www.youtube.com/watch?v=\(id)" + (start.map { "&t=\($0)s" } ?? "")
        }
        return ParsedLink(
            provider: .youtube,
            videoID: id,
            canonicalURL: URL(string: canonical)!,
            aspect: shorts ? .portrait : .landscape,
            startSeconds: start
        )
    }
}
