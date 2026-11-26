import XCTest
@testable import DeliciousCore

@MainActor
final class LibraryTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func added(_ result: Library.AddResult, file: StaticString = #filePath, line: UInt = #line) -> VideoLink? {
        guard case let .added(link) = result else {
            XCTFail("expected .added, got \(result)", file: file, line: line)
            return nil
        }
        return link
    }

    func testAddInvalidAndDuplicate() {
        let library = Library(fileURL: nil)
        XCTAssertEqual(library.add("hello"), .invalid)
        let first = added(library.add("https://youtu.be/dQw4w9WgXcQ"))
        XCTAssertEqual(first?.status, .queued)
        guard case .duplicate(let dup) = library.add("watch https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share") else {
            return XCTFail("expected duplicate")
        }
        XCTAssertEqual(dup.id, first?.id)
        XCTAssertEqual(library.items.count, 1)
    }

    func testQueueIsNewestFirstAndDecisionsMoveItems() {
        let library = Library(fileURL: nil)
        let a = added(library.add("https://youtu.be/aaaaaaaaaaa"))!
        let b = added(library.add("https://youtu.be/bbbbbbbbbbb"))!
        let c = added(library.add("https://youtu.be/ccccccccccc"))!
        XCTAssertEqual(library.queue.map(\.id), [c.id, b.id, a.id])

        library.decide(c.id, .keep)
        library.decide(b.id, .archive)
        library.decide(a.id, .favorite)
        XCTAssertTrue(library.queue.isEmpty)
        XCTAssertEqual(library.item(c.id)?.status, .kept)
        XCTAssertEqual(library.item(b.id)?.status, .archived)
        XCTAssertEqual(library.item(a.id)?.status, .kept)
        XCTAssertEqual(library.item(a.id)?.isFavorite, true)
        XCTAssertNotNil(library.item(a.id)?.reviewedAt)
    }

    func testUndoRestoresPreviousState() {
        let library = Library(fileURL: nil)
        let a = added(library.add("https://youtu.be/aaaaaaaaaaa"))!
        XCTAssertFalse(library.canUndo)
        library.decide(a.id, .favorite)
        XCTAssertTrue(library.canUndo)
        library.undo()
        XCTAssertEqual(library.item(a.id)?.status, .queued)
        XCTAssertEqual(library.item(a.id)?.isFavorite, false)
        XCTAssertFalse(library.canUndo)

        library.delete(a.id)
        XCTAssertNil(library.item(a.id))
        library.undo()
        XCTAssertNotNil(library.item(a.id))
    }

    func testPersistsAcrossLaunches() {
        let file = tempDir.appendingPathComponent("library.json")
        let library = Library(fileURL: file)
        let a = added(library.add("https://x.com/a/status/42"))!
        library.decide(a.id, .favorite)
        var enriched = library.item(a.id)!
        enriched.title = "Dog on a skateboard"
        enriched.tags = ["dogs"]
        enriched.enriched = true
        library.applyEnrichment(enriched)

        let reopened = Library(fileURL: file)
        XCTAssertEqual(reopened.items.count, 1)
        let loaded = reopened.items[0]
        XCTAssertEqual(loaded.id, a.id)
        XCTAssertEqual(loaded.title, "Dog on a skateboard")
        XCTAssertEqual(loaded.tags, ["dogs"])
        XCTAssertTrue(loaded.isFavorite)
        XCTAssertEqual(loaded.status, .kept)
        XCTAssertEqual(loaded.provider, .x)
    }

    func testEnrichmentDoesNotUndoASwipe() {
        let library = Library(fileURL: nil)
        let a = added(library.add("https://youtu.be/aaaaaaaaaaa"))!
        var snapshot = a // taken before the user swiped
        library.decide(a.id, .archive)
        snapshot.title = "Fetched title"
        snapshot.enriched = true
        library.applyEnrichment(snapshot)
        XCTAssertEqual(library.item(a.id)?.status, .archived)
        XCTAssertEqual(library.item(a.id)?.title, "Fetched title")
    }

    func testFiltersTagsAndSearch() {
        let library = Library(fileURL: nil)
        let a = added(library.add("https://youtu.be/aaaaaaaaaaa"))!
        let b = added(library.add("https://www.tiktok.com/@anna/video/123"))!
        let c = added(library.add("https://vimeo.com/76979871"))!
        for (link, title, tags) in [(a, "Pasta night", ["cooking", "food"]), (b, "Dumplings", ["cooking"]), (c, "Mountain bike", ["sports"])] {
            var l = link
            l.title = title
            l.tags = tags
            library.applyEnrichment(l)
        }
        library.decide(a.id, .favorite)
        library.decide(c.id, .archive)

        XCTAssertEqual(Set(library.filtered(.all).map(\.id)), [a.id, b.id])
        XCTAssertEqual(library.filtered(.favorites).map(\.id), [a.id])
        XCTAssertEqual(library.filtered(.archived).map(\.id), [c.id])
        XCTAssertEqual(Set(library.filtered(.tag("cooking")).map(\.id)), [a.id, b.id])
        XCTAssertEqual(library.filtered(.provider(.tiktok)).map(\.id), [b.id])
        XCTAssertEqual(library.filtered(.all, search: "PASTA").map(\.id), [a.id])
        XCTAssertEqual(library.filtered(.all, search: "tiktok").map(\.id), [b.id])
        XCTAssertEqual(library.allTags, ["cooking", "food"])
        XCTAssertEqual(library.providersInUse, [.youtube, .tiktok])
    }
}
