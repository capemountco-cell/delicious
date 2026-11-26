import Foundation

/// How a saved video should be shown inside the app.
public enum PlayerSource: Equatable, Sendable {
    /// A video file the phone can play itself.
    case native(URL)
    /// A site's own embedded player, wrapped in a tiny page.
    case embed(src: URL, html: String, baseURL: URL)
    /// No embeddable player is known: show the page itself.
    case page(URL)
}

public enum EmbedBuilder {
    /// The origin our wrapper pages pretend to come from. Some players (YouTube) require
    /// a referrer that identifies the app.
    public static let appOrigin = URL(string: "https://com.capemount.delicious")!

    public static func source(for link: VideoLink) -> PlayerSource {
        guard let src = embedURL(for: link) else {
            return link.provider == .directFile ? .native(link.url) : .page(link.url)
        }
        return .embed(src: src, html: wrapperHTML(src: src), baseURL: appOrigin)
    }

    public static func embedURL(for link: VideoLink) -> URL? {
        let id = link.videoID
        switch link.provider {
        case .youtube:
            guard let id else { return nil }
            var query = "playsinline=1&rel=0&modestbranding=1"
            if let start = LinkParser.parse(link.url).startSeconds { query += "&start=\(start)" }
            return URL(string: "https://www.youtube.com/embed/\(id)?\(query)")
        case .vimeo:
            guard let id else { return nil }
            let pieces = id.split(separator: "/").map(String.init)
            var s = "https://player.vimeo.com/video/\(pieces[0])?playsinline=1&dnt=1"
            if pieces.count > 1 { s += "&h=\(pieces[1])" }
            return URL(string: s)
        case .x:
            guard let id else { return nil }
            return URL(string: "https://platform.twitter.com/embed/Tweet.html?id=\(id)&theme=dark&dnt=true")
        case .tiktok:
            guard let id else { return nil }
            return URL(string: "https://www.tiktok.com/player/v1/\(id)?description=1&music_info=1&rel=0")
        case .instagram:
            guard let id else { return nil }
            return URL(string: "https://www.instagram.com/\(id)/embed/")
        case .facebook:
            return URL(string: "https://www.facebook.com/plugins/video.php?href=\(encode(link.url.absoluteString))&show_text=false")
        case .dailymotion:
            guard let id else { return nil }
            return URL(string: "https://www.dailymotion.com/embed/video/\(id)")
        case .loom:
            guard let id else { return nil }
            return URL(string: "https://www.loom.com/embed/\(id)")
        case .streamable:
            guard let id else { return nil }
            return URL(string: "https://streamable.com/e/\(id)")
        case .reddit:
            guard id != nil, var c = URLComponents(url: link.url, resolvingAgainstBaseURL: false) else { return nil }
            c.host = "embed.reddit.com"
            c.query = nil
            return c.url
        case .twitch:
            guard let id, let parent = appOrigin.host else { return nil }
            let pieces = id.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return nil }
            switch pieces[0] {
            case "clip": return URL(string: "https://clips.twitch.tv/embed?clip=\(pieces[1])&parent=\(parent)")
            case "video": return URL(string: "https://player.twitch.tv/?video=\(pieces[1])&parent=\(parent)&autoplay=false")
            case "channel": return URL(string: "https://player.twitch.tv/?channel=\(pieces[1])&parent=\(parent)&autoplay=false")
            default: return nil
            }
        case .directFile, .web:
            return nil
        }
    }

    public static func wrapperHTML(src: URL) -> String {
        let escaped = src.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html><html><head><meta charset="utf-8">\
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">\
        <meta name="referrer" content="strict-origin-when-cross-origin">\
        <style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}\
        iframe{position:absolute;top:0;left:0;width:100%;height:100%;border:0}</style></head>\
        <body><iframe src="\(escaped)" allow="autoplay; encrypted-media; picture-in-picture; fullscreen; clipboard-write" \
        allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>
        """
    }

    static func encode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
