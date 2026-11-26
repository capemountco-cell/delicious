import Foundation

/// Where a saved video lives.
public enum Provider: String, Codable, CaseIterable, Sendable {
    case youtube, vimeo, x, tiktok, instagram, facebook, dailymotion, loom, streamable, reddit, twitch
    case directFile
    case web

    public var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .vimeo: return "Vimeo"
        case .x: return "X"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .dailymotion: return "Dailymotion"
        case .loom: return "Loom"
        case .streamable: return "Streamable"
        case .reddit: return "Reddit"
        case .twitch: return "Twitch"
        case .directFile: return "Video file"
        case .web: return "Web"
        }
    }

    /// SF Symbol used for the provider badge.
    public var symbolName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .vimeo: return "v.circle.fill"
        case .x: return "xmark"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .facebook: return "f.circle.fill"
        case .dailymotion: return "d.circle.fill"
        case .loom: return "record.circle"
        case .streamable: return "s.circle.fill"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .twitch: return "gamecontroller.fill"
        case .directFile: return "film"
        case .web: return "globe"
        }
    }
}

public enum VideoAspect: String, Codable, Sendable {
    case landscape, portrait, square

    /// Width divided by height.
    public var ratio: Double {
        switch self {
        case .landscape: return 16.0 / 9.0
        case .portrait: return 9.0 / 16.0
        case .square: return 1
        }
    }
}

public enum VideoStatus: String, Codable, Sendable {
    /// Saved, waiting to be reviewed.
    case queued
    /// Reviewed and kept in the library.
    case kept
    /// Watched / dismissed.
    case archived
}

public struct VideoLink: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// Cleaned-up link used for playback and duplicate detection.
    public var url: URL
    /// Exactly what was pasted.
    public var originalURL: URL
    public var provider: Provider
    public var videoID: String?
    public var aspect: VideoAspect
    /// Display title (possibly tidied).
    public var title: String?
    /// Title as published by the source site.
    public var sourceTitle: String?
    public var author: String?
    public var thumbnailURL: URL?
    /// File name of a thumbnail generated on the phone (for direct video files).
    public var localThumbnailName: String?
    public var tags: [String]
    public var duration: Double?
    public var status: VideoStatus
    public var isFavorite: Bool
    public var addedAt: Date
    public var reviewedAt: Date?
    /// True once we have tried to fetch details for this link.
    public var enriched: Bool

    public init(parsed: ParsedLink, originalURL: URL, id: UUID = UUID(), addedAt: Date = Date()) {
        self.id = id
        self.url = parsed.canonicalURL
        self.originalURL = originalURL
        self.provider = parsed.provider
        self.videoID = parsed.videoID
        self.aspect = parsed.aspect
        self.title = nil
        self.sourceTitle = nil
        self.author = nil
        self.thumbnailURL = nil
        self.localThumbnailName = nil
        self.tags = []
        self.duration = nil
        self.status = .queued
        self.isFavorite = false
        self.addedAt = addedAt
        self.reviewedAt = nil
        self.enriched = false
    }

    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let sourceTitle, !sourceTitle.isEmpty { return sourceTitle }
        switch provider {
        case .x: return "Post on X"
        case .web: return url.host ?? "Saved video"
        case .directFile: return url.deletingPathExtension().lastPathComponent
        default: return "\(provider.displayName) video"
        }
    }

    /// Replace the location fields with a freshly parsed link (e.g. after following a short link).
    public mutating func apply(_ parsed: ParsedLink) {
        url = parsed.canonicalURL
        provider = parsed.provider
        videoID = parsed.videoID
        aspect = parsed.aspect
    }

    public func matches(_ parsed: ParsedLink) -> Bool {
        if provider == parsed.provider, let videoID, let other = parsed.videoID {
            return videoID == other
        }
        return url.absoluteString == parsed.canonicalURL.absoluteString
            || originalURL.absoluteString == parsed.canonicalURL.absoluteString
    }
}
