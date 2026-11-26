import XCTest
@testable import DeliciousCore

final class TidyClientTests: XCTestCase {
    let endpoint = URL(string: "https://example.lovable.app/api/tidy")!

    func testReturnsCleanTitleAndTags() async throws {
        let http = StubHTTP()
        http.on(endpoint.absoluteString, json: #"{"title":"  Perfect pasta carbonara ","tags":["Cooking","cooking","Italian","food","extra"]}"#)
        let client = TidyClient(endpoint: endpoint, http: http)
        let result = await client.tidy(url: URL(string: "https://youtu.be/dQw4w9WgXcQ")!, title: "PERFECT Pasta!!! 🍝", author: "Chef", provider: "YouTube")
        XCTAssertEqual(result, TidyResult(title: "Perfect pasta carbonara", tags: ["cooking", "italian", "food"]))

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body?["url"], "https://youtu.be/dQw4w9WgXcQ")
        XCTAssertEqual(body?["title"], "PERFECT Pasta!!! 🍝")
        XCTAssertEqual(body?["provider"], "YouTube")
    }

    func testSilentlyFallsBack() async {
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ")!

        // No server configured.
        let none = await TidyClient(endpoint: nil, http: StubHTTP()).tidy(url: url, title: nil, author: nil, provider: "YouTube")
        XCTAssertNil(none)

        // Server says "nothing for you" (e.g. key not set).
        let empty = StubHTTP()
        empty.on(endpoint.absoluteString, status: 204)
        let noContent = await TidyClient(endpoint: endpoint, http: empty).tidy(url: url, title: nil, author: nil, provider: "YouTube")
        XCTAssertNil(noContent)

        // Offline.
        let offline = StubHTTP()
        offline.failAll = true
        let failed = await TidyClient(endpoint: endpoint, http: offline).tidy(url: url, title: nil, author: nil, provider: "YouTube")
        XCTAssertNil(failed)

        // Garbage reply.
        let garbage = StubHTTP()
        garbage.on(endpoint.absoluteString, json: "<html>oops</html>")
        let bad = await TidyClient(endpoint: endpoint, http: garbage).tidy(url: url, title: nil, author: nil, provider: "YouTube")
        XCTAssertNil(bad)

        // Empty title.
        let blank = StubHTTP()
        blank.on(endpoint.absoluteString, json: #"{"title":"  ","tags":[]}"#)
        let blankTitle = await TidyClient(endpoint: endpoint, http: blank).tidy(url: url, title: nil, author: nil, provider: "YouTube")
        XCTAssertNil(blankTitle)
    }
}

final class MetadataFetcherTests: XCTestCase {
    func testYouTubeOEmbed() async throws {
        let http = StubHTTP()
        http.on("https://www.youtube.com/oembed", json: #"{"title":"Never Gonna Give You Up","author_name":"Rick Astley","thumbnail_url":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"}"#)
        let parsed = LinkParser.parse(URL(string: "https://youtu.be/dQw4w9WgXcQ")!)
        let meta = await MetadataFetcher(http: http).fetch(for: parsed)
        XCTAssertEqual(meta?.title, "Never Gonna Give You Up")
        XCTAssertEqual(meta?.author, "Rick Astley")
        XCTAssertEqual(meta?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        let requested = try XCTUnwrap(http.requestedURLs.first)
        XCTAssertTrue(requested.contains("url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DdQw4w9WgXcQ"), requested)
    }

    func testYouTubeThumbnailEvenWhenOffline() async {
        let http = StubHTTP()
        http.failAll = true
        let parsed = LinkParser.parse(URL(string: "https://youtu.be/dQw4w9WgXcQ")!)
        let meta = await MetadataFetcher(http: http).fetch(for: parsed)
        XCTAssertEqual(meta?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
        XCTAssertNil(meta?.title)
    }

    func testXPost() async {
        let http = StubHTTP()
        http.on("https://api.fxtwitter.com/status/42", json: #"{"code":200,"tweet":{"text":"\nthis dog can skateboard 🛹\nmore text","author":{"name":"Dog Fan","screen_name":"dogfan"},"media":{"videos":[{"thumbnail_url":"https://pbs.twimg.com/thumb.jpg","duration":12.5}]}}}"#)
        let meta = await MetadataFetcher(http: http).fetch(for: LinkParser.parse(URL(string: "https://x.com/dogfan/status/42")!))
        XCTAssertEqual(meta?.title, "this dog can skateboard 🛹")
        XCTAssertEqual(meta?.author, "Dog Fan")
        XCTAssertEqual(meta?.thumbnailURL?.absoluteString, "https://pbs.twimg.com/thumb.jpg")
        XCTAssertEqual(meta?.duration, 12.5)
    }

    func testTikTokShortLinkGetsVideoID() async {
        let http = StubHTTP()
        http.on("https://www.tiktok.com/oembed", json: #"{"title":"Easy dumplings","author_name":"Anna","thumbnail_url":"https://p16.tiktokcdn.com/t.jpg","embed_product_id":"7301234567890123456"}"#)
        let meta = await MetadataFetcher(http: http).fetch(for: LinkParser.parse(URL(string: "https://vm.tiktok.com/ZMabc/")!))
        XCTAssertEqual(meta?.videoID, "7301234567890123456")
        XCTAssertEqual(meta?.title, "Easy dumplings")
    }

    func testOpenGraphFallback() async {
        let http = StubHTTP()
        http.on("https://www.instagram.com/reel/ABC/", html: """
        <html><head><title>ignored</title>
        <meta content="Sunset surf session &amp; friends" property="og:title" />
        <meta property='og:image' content='https://cdn.example.com/surf.jpg'>
        <meta name="author" content="surfer">
        </head></html>
        """)
        let meta = await MetadataFetcher(http: http).fetch(for: LinkParser.parse(URL(string: "https://www.instagram.com/reel/ABC/")!))
        XCTAssertEqual(meta?.title, "Sunset surf session & friends")
        XCTAssertEqual(meta?.thumbnailURL?.absoluteString, "https://cdn.example.com/surf.jpg")
        XCTAssertEqual(meta?.author, "surfer")
    }

    func testOpenGraphParsingDetails() {
        let base = URL(string: "https://example.com/videos/1")!
        let meta = MetadataFetcher.parseOpenGraph(html: "<title>Plain &#8216;title&#8217;</title><meta property=\"og:image\" content=\"/img/a.png\">", baseURL: base)
        XCTAssertEqual(meta?.title, "Plain \u{2018}title\u{2019}")
        XCTAssertEqual(meta?.thumbnailURL?.absoluteString, "https://example.com/img/a.png")
        XCTAssertNil(MetadataFetcher.parseOpenGraph(html: "<p>nothing</p>", baseURL: base))
    }

    func testResolveRedirects() async {
        let http = StubHTTP()
        http.on("https://t.co/abc", finalURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!)
        let final = await MetadataFetcher(http: http).resolveRedirects(URL(string: "https://t.co/abc")!)
        XCTAssertEqual(final?.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }
}

final class EnricherTests: XCTestCase {
    func testShortLinkIsFollowedThenTidied() async {
        let http = StubHTTP()
        let endpoint = URL(string: "https://example.lovable.app/api/tidy")!
        http.on("https://t.co/abc", finalURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=10")!)
        http.on("https://www.youtube.com/oembed", json: #"{"title":"NEVER GONNA GIVE YOU UP (Official Video) | Rick","author_name":"Rick Astley"}"#)
        http.on(endpoint.absoluteString, json: #"{"title":"Never Gonna Give You Up","tags":["music","80s"]}"#)

        let url = URL(string: "https://t.co/abc")!
        let link = VideoLink(parsed: LinkParser.parse(url), originalURL: url)
        XCTAssertEqual(link.provider, .web)

        let enriched = await Enricher(http: http, tidyEndpoint: endpoint, thumbnailDirectory: nil).enrich(link)
        XCTAssertEqual(enriched.provider, .youtube)
        XCTAssertEqual(enriched.videoID, "dQw4w9WgXcQ")
        XCTAssertEqual(enriched.sourceTitle, "NEVER GONNA GIVE YOU UP (Official Video) | Rick")
        XCTAssertEqual(enriched.title, "Never Gonna Give You Up")
        XCTAssertEqual(enriched.displayTitle, "Never Gonna Give You Up")
        XCTAssertEqual(enriched.tags, ["music", "80s"])
        XCTAssertEqual(enriched.author, "Rick Astley")
        XCTAssertNotNil(enriched.thumbnailURL)
        XCTAssertTrue(enriched.enriched)
        XCTAssertEqual(enriched.status, .queued)
    }

    func testWorksWithoutServer() async {
        let http = StubHTTP()
        http.on("https://www.youtube.com/oembed", json: #"{"title":"Original title","author_name":"Someone"}"#)
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ")!
        let link = VideoLink(parsed: LinkParser.parse(url), originalURL: url)
        let enriched = await Enricher(http: http, tidyEndpoint: nil, thumbnailDirectory: nil).enrich(link)
        XCTAssertEqual(enriched.displayTitle, "Original title")
        XCTAssertNil(enriched.title)
        XCTAssertEqual(enriched.tags, [])
        XCTAssertTrue(enriched.enriched)
    }

    func testWorksFullyOffline() async {
        let http = StubHTTP()
        http.failAll = true
        let url = URL(string: "https://x.com/a/status/42")!
        let link = VideoLink(parsed: LinkParser.parse(url), originalURL: url)
        let enriched = await Enricher(http: http, tidyEndpoint: URL(string: "https://example.com/api/tidy"), thumbnailDirectory: nil).enrich(link)
        XCTAssertEqual(enriched.displayTitle, "Post on X")
        XCTAssertTrue(enriched.enriched)
    }
}
