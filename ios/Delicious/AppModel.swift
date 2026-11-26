import DeliciousCore
import Foundation
import Observation

enum AppTab: Hashable {
    case review, library
}

@MainActor
@Observable
final class AppModel {
    let library: Library
    var tab: AppTab = .review
    var showAdd = false
    var showInfo = false
    /// Bumped on every review decision so views can play a haptic.
    var decisionCount = 0

    @ObservationIgnored private let enricher: Enricher
    @ObservationIgnored private var inFlight: Set<UUID> = []

    static let thumbnailDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Thumbnails", isDirectory: true)
    }()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Delicious", isDirectory: true)
        library = Library(fileURL: support.appendingPathComponent("library.json"))

        let configured = (Bundle.main.object(forInfoDictionaryKey: "DLTidyEndpoint") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let endpoint = configured.hasPrefix("https://") ? URL(string: configured) : nil

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        enricher = Enricher(http: URLSession(configuration: config), tidyEndpoint: endpoint, thumbnailDirectory: Self.thumbnailDirectory)

        Task { await enrichPending() }
    }

    // MARK: - Adding

    @discardableResult
    func add(_ text: String) -> Library.AddResult {
        let result = library.add(text)
        if case .added(let link) = result {
            tab = .review
            Task { await enrich(link) }
        }
        return result
    }

    func handleOpenURL(_ url: URL) {
        // delicious://add?url=https://…  (handy from Shortcuts)
        guard url.scheme == "delicious",
              let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value
        else { return }
        add(target)
    }

    // MARK: - Reviewing

    func decide(_ id: UUID, _ decision: Decision) {
        library.decide(id, decision)
        decisionCount += 1
    }

    func undo() {
        library.undo()
        decisionCount += 1
    }

    // MARK: - Details

    private func enrich(_ link: VideoLink) async {
        guard !inFlight.contains(link.id) else { return }
        inFlight.insert(link.id)
        defer { inFlight.remove(link.id) }
        let updated = await enricher.enrich(link)
        library.applyEnrichment(updated)
    }

    private func enrichPending() async {
        for link in library.items where !link.enriched {
            await enrich(link)
        }
    }

    static func localThumbnail(for link: VideoLink) -> URL? {
        link.localThumbnailName.map { thumbnailDirectory.appendingPathComponent($0) }
    }
}
