import Foundation

/// Fills in a freshly saved link: follows short links, fetches title/thumbnail,
/// probes direct video files, then asks the server for a tidy title and tags.
/// Every step is optional — if one fails we simply keep what we have.
public struct Enricher: Sendable {
    public let metadata: MetadataFetcher
    public let tidy: TidyClient
    public let thumbnailDirectory: URL?

    public init(http: any HTTPClient, tidyEndpoint: URL?, thumbnailDirectory: URL?) {
        self.metadata = MetadataFetcher(http: http)
        self.tidy = TidyClient(endpoint: tidyEndpoint, http: http)
        self.thumbnailDirectory = thumbnailDirectory
    }

    public func enrich(_ input: VideoLink) async -> VideoLink {
        var link = input

        if LinkParser.needsRedirectResolution(link.url), let resolved = await metadata.resolveRedirects(link.url) {
            link.apply(LinkParser.parse(resolved))
        }

        if link.provider == .directFile {
            if let info = await MediaProbe.probe(link.url) {
                if info.duration > 0 { link.duration = info.duration }
                if info.hasVideo { link.aspect = info.aspect }
            }
            if let dir = thumbnailDirectory, let image = await MediaProbe.thumbnail(for: link.url) {
                let name = "\(link.id.uuidString).jpg"
                if MediaProbe.writeJPEG(image, to: dir.appendingPathComponent(name)) {
                    link.localThumbnailName = name
                }
            }
            if link.sourceTitle == nil {
                let fileName = link.url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                link.sourceTitle = fileName.isEmpty ? nil : fileName
            }
        } else if let meta = await metadata.fetch(for: LinkParser.parse(link.url)) {
            if let title = meta.title { link.sourceTitle = title }
            if let author = meta.author { link.author = author }
            if let thumb = meta.thumbnailURL { link.thumbnailURL = thumb }
            if let duration = meta.duration, duration > 0 { link.duration = duration }
            if link.videoID == nil, let id = meta.videoID { link.videoID = id }
        }

        if let tidied = await tidy.tidy(
            url: link.url,
            title: link.sourceTitle,
            author: link.author,
            provider: link.provider.displayName
        ) {
            link.title = tidied.title
            link.tags = tidied.tags
        }

        link.enriched = true
        return link
    }
}
