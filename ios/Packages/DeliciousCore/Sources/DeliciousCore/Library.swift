import Foundation
import Observation

public enum Decision: Sendable {
    case keep, archive, favorite
}

public enum LibraryFilter: Hashable, Sendable {
    case all, favorites, archived
    case tag(String)
    case provider(Provider)
}

/// The saved videos, persisted as a small JSON file on the phone.
@MainActor
@Observable
public final class Library {
    public enum AddResult: Equatable {
        case added(VideoLink)
        case duplicate(VideoLink)
        case invalid
    }

    struct UndoEntry {
        let previous: VideoLink
        let wasDeleted: Bool
    }

    private struct Archive: Codable {
        var version = 1
        var items: [VideoLink]
    }

    /// Newest first.
    public private(set) var items: [VideoLink] = []
    private var undoStack: [UndoEntry] = []
    @ObservationIgnored private let fileURL: URL?

    public init(fileURL: URL?) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Queries

    public var queue: [VideoLink] { items.filter { $0.status == .queued } }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var isEmpty: Bool { items.isEmpty }

    public func item(_ id: UUID) -> VideoLink? { items.first { $0.id == id } }

    /// Tags across the library, most used first.
    public var allTags: [String] {
        var counts: [String: Int] = [:]
        for link in items where link.status != .archived {
            for tag in link.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    public var providersInUse: [Provider] {
        let used = Set(items.filter { $0.status != .archived }.map(\.provider))
        return Provider.allCases.filter { used.contains($0) }
    }

    public func filtered(_ filter: LibraryFilter, search: String = "") -> [VideoLink] {
        let base: [VideoLink]
        switch filter {
        case .all: base = items.filter { $0.status != .archived }
        case .favorites: base = items.filter { $0.isFavorite && $0.status != .archived }
        case .archived: base = items.filter { $0.status == .archived }
        case .tag(let tag): base = items.filter { $0.tags.contains(tag) && $0.status != .archived }
        case .provider(let p): base = items.filter { $0.provider == p && $0.status != .archived }
        }
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return base }
        return base.filter { link in
            let haystack = [link.displayTitle, link.sourceTitle ?? "", link.author ?? "", link.provider.displayName, link.url.host ?? ""]
                + link.tags
            return haystack.contains { $0.lowercased().contains(needle) }
        }
    }

    // MARK: - Changes

    @discardableResult
    public func add(_ text: String) -> AddResult {
        guard let url = LinkParser.extractURL(from: text) else { return .invalid }
        let parsed = LinkParser.parse(url)
        if let existing = items.first(where: { $0.matches(parsed) }) { return .duplicate(existing) }
        let link = VideoLink(parsed: parsed, originalURL: url)
        items.insert(link, at: 0)
        persist()
        return .added(link)
    }

    public func decide(_ id: UUID, _ decision: Decision) {
        guard let i = index(id) else { return }
        pushUndo(items[i], deleted: false)
        switch decision {
        case .keep:
            items[i].status = .kept
        case .archive:
            items[i].status = .archived
        case .favorite:
            items[i].status = .kept
            items[i].isFavorite = true
        }
        items[i].reviewedAt = Date()
        persist()
    }

    public func setStatus(_ id: UUID, _ status: VideoStatus) {
        guard let i = index(id), items[i].status != status else { return }
        pushUndo(items[i], deleted: false)
        items[i].status = status
        persist()
    }

    public func toggleFavorite(_ id: UUID) {
        guard let i = index(id) else { return }
        items[i].isFavorite.toggle()
        persist()
    }

    public func delete(_ id: UUID) {
        guard let i = index(id) else { return }
        pushUndo(items[i], deleted: true)
        items.remove(at: i)
        persist()
    }

    /// Reverses the last review decision, status change or delete.
    @discardableResult
    public func undo() -> VideoLink? {
        guard let entry = undoStack.popLast() else { return nil }
        if entry.wasDeleted || index(entry.previous.id) == nil {
            items.insert(entry.previous, at: 0)
        } else if let i = index(entry.previous.id) {
            items[i].status = entry.previous.status
            items[i].isFavorite = entry.previous.isFavorite
            items[i].reviewedAt = entry.previous.reviewedAt
        }
        persist()
        return entry.previous
    }

    /// Copies fetched details onto a saved link without touching review state
    /// (the user may have swiped it while details were loading).
    public func applyEnrichment(_ enriched: VideoLink) {
        guard let i = index(enriched.id) else { return }
        var link = items[i]
        link.url = enriched.url
        link.provider = enriched.provider
        link.videoID = enriched.videoID
        link.aspect = enriched.aspect
        link.title = enriched.title
        link.sourceTitle = enriched.sourceTitle
        link.author = enriched.author
        link.thumbnailURL = enriched.thumbnailURL
        link.localThumbnailName = enriched.localThumbnailName
        link.tags = enriched.tags
        link.duration = enriched.duration
        link.enriched = enriched.enriched
        items[i] = link
        persist()
    }

    // MARK: - Private

    private func index(_ id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    private func pushUndo(_ link: VideoLink, deleted: Bool) {
        undoStack.append(UndoEntry(previous: link, wasDeleted: deleted))
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let archive = try? decoder.decode(Archive.self, from: data) {
            items = archive.items
        }
    }

    private func persist() {
        guard let fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Archive(items: items)) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
