import XCTest
@testable import DeliciousCore

final class LinkParserTests: XCTestCase {
    private func parse(_ s: String) -> ParsedLink { LinkParser.parse(URL(string: s)!) }

    func testExtractsLinkFromSharedText() {
        let url = LinkParser.extractURL(from: "lol watch this https://youtu.be/dQw4w9WgXcQ?si=abc 🔥")
        XCTAssertEqual(url?.host, "youtu.be")
        XCTAssertNil(LinkParser.extractURL(from: "no link here"))
        XCTAssertNil(LinkParser.extractURL(from: "   "))
        XCTAssertNil(LinkParser.extractURL(from: "mailto:someone@example.com"))
    }

    func testExtractsBareDomain() {
        let url = LinkParser.extractURL(from: "youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertNotNil(url)
        XCTAssertEqual(url.map(LinkParser.parse)?.provider, .youtube)
    }

    func testYouTubeVariants() {
        for s in [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=share",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://www.youtube.com/embed/dQw4w9WgXcQ",
            "https://www.youtube.com/live/dQw4w9WgXcQ",
            "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
        ] {
            let p = parse(s)
            XCTAssertEqual(p.provider, .youtube, s)
            XCTAssertEqual(p.videoID, "dQw4w9WgXcQ", s)
            XCTAssertEqual(p.aspect, .landscape, s)
        }
        XCTAssertEqual(parse("https://youtu.be/dQw4w9WgXcQ").canonicalURL.absoluteString, "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testYouTubeShortsAreVertical() {
        let p = parse("https://youtube.com/shorts/abcdefghijk?feature=share")
        XCTAssertEqual(p.videoID, "abcdefghijk")
        XCTAssertEqual(p.aspect, .portrait)
        XCTAssertEqual(p.canonicalURL.absoluteString, "https://www.youtube.com/shorts/abcdefghijk")
    }

    func testYouTubeStartTime() {
        XCTAssertEqual(parse("https://youtu.be/dQw4w9WgXcQ?t=90").startSeconds, 90)
        XCTAssertEqual(parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s").startSeconds, 90)
        XCTAssertEqual(parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1h0m5s").startSeconds, 3605)
        XCTAssertNil(parse("https://www.youtube.com/watch?v=dQw4w9WgXcQ").startSeconds)
    }

    func testYouTubeChannelIsJustAWebPage() {
        XCTAssertEqual(parse("https://www.youtube.com/@somechannel").provider, .web)
    }

    func testXAndTwitter() {
        for s in [
            "https://x.com/someone/status/1234567890123456789",
            "https://twitter.com/someone/status/1234567890123456789?s=20",
            "https://mobile.twitter.com/someone/status/1234567890123456789/video/1",
            "https://fxtwitter.com/someone/status/1234567890123456789",
        ] {
            let p = parse(s)
            XCTAssertEqual(p.provider, .x, s)
            XCTAssertEqual(p.videoID, "1234567890123456789", s)
            XCTAssertEqual(p.canonicalURL.absoluteString, "https://x.com/someone/status/1234567890123456789", s)
        }
        XCTAssertEqual(parse("https://x.com/i/web/status/42").canonicalURL.absoluteString, "https://x.com/i/status/42")
        XCTAssertEqual(parse("https://x.com/someone").provider, .web)
    }

    func testTikTok() {
        let p = parse("https://www.tiktok.com/@chef.anna/video/7301234567890123456?is_from_webapp=1")
        XCTAssertEqual(p.provider, .tiktok)
        XCTAssertEqual(p.videoID, "7301234567890123456")
        XCTAssertEqual(p.aspect, .portrait)
        XCTAssertEqual(p.canonicalURL.absoluteString, "https://www.tiktok.com/@chef.anna/video/7301234567890123456")
        XCTAssertEqual(parse("https://www.tiktok.com/embed/v2/7301234567890123456").videoID, "7301234567890123456")
        XCTAssertEqual(parse("https://m.tiktok.com/v/7301234567890123456.html").videoID, "7301234567890123456")
        let short = parse("https://vm.tiktok.com/ZMabc123/")
        XCTAssertEqual(short.provider, .tiktok)
        XCTAssertNil(short.videoID)
    }

    func testInstagram() {
        let reel = parse("https://www.instagram.com/reel/C1a2B3c4D5e/?igsh=xyz")
        XCTAssertEqual(reel.provider, .instagram)
        XCTAssertEqual(reel.videoID, "reel/C1a2B3c4D5e")
        XCTAssertEqual(reel.aspect, .portrait)
        XCTAssertEqual(parse("https://instagram.com/reels/C1a2B3c4D5e/").videoID, "reel/C1a2B3c4D5e")
        let post = parse("https://www.instagram.com/someone/p/C1a2B3c4D5e/")
        XCTAssertEqual(post.videoID, "p/C1a2B3c4D5e")
        XCTAssertEqual(post.aspect, .square)
    }

    func testVimeo() {
        XCTAssertEqual(parse("https://vimeo.com/76979871").videoID, "76979871")
        XCTAssertEqual(parse("https://vimeo.com/channels/staffpicks/76979871").videoID, "76979871")
        XCTAssertEqual(parse("https://player.vimeo.com/video/76979871").videoID, "76979871")
        let unlisted = parse("https://vimeo.com/76979871/abcdef1234")
        XCTAssertEqual(unlisted.videoID, "76979871/abcdef1234")
        XCTAssertEqual(unlisted.canonicalURL.absoluteString, "https://vimeo.com/76979871/abcdef1234")
    }

    func testOtherProviders() {
        XCTAssertEqual(parse("https://www.dailymotion.com/video/x8abc12_some-title").videoID, "x8abc12")
        XCTAssertEqual(parse("https://dai.ly/x8abc12").videoID, "x8abc12")
        XCTAssertEqual(parse("https://www.loom.com/share/0123456789abcdef").videoID, "0123456789abcdef")
        XCTAssertEqual(parse("https://streamable.com/moo12").videoID, "moo12")
        XCTAssertEqual(parse("https://streamable.com/e/moo12").videoID, "moo12")
        XCTAssertEqual(parse("https://www.reddit.com/r/videos/comments/abc123/funny/").videoID, "abc123")
        XCTAssertEqual(parse("https://clips.twitch.tv/FunnyClipSlug").videoID, "clip:FunnyClipSlug")
        XCTAssertEqual(parse("https://www.twitch.tv/somestreamer/clip/FunnyClipSlug").videoID, "clip:FunnyClipSlug")
        XCTAssertEqual(parse("https://www.twitch.tv/videos/123456").videoID, "video:123456")
        XCTAssertEqual(parse("https://www.facebook.com/someone/videos/123456789/").provider, .facebook)
        XCTAssertEqual(parse("https://www.facebook.com/reel/123456789").aspect, .portrait)
    }

    func testDirectFilesAndWeb() {
        XCTAssertEqual(parse("https://cdn.example.com/clips/beach.mp4").provider, .directFile)
        XCTAssertEqual(parse("https://cdn.example.com/live/index.m3u8?token=1").provider, .directFile)
        XCTAssertEqual(parse("https://example.com/some/article").provider, .web)
    }

    func testShortLinksNeedResolving() {
        for s in ["https://t.co/AbC123", "https://vm.tiktok.com/ZMabc/", "https://www.tiktok.com/t/ZTabc/", "https://bit.ly/3xyz", "https://www.reddit.com/r/videos/s/AbCdEf", "https://fb.watch/abc/"] {
            XCTAssertTrue(LinkParser.needsRedirectResolution(URL(string: s)!), s)
        }
        XCTAssertFalse(LinkParser.needsRedirectResolution(URL(string: "https://youtu.be/dQw4w9WgXcQ")!))
        XCTAssertFalse(LinkParser.needsRedirectResolution(URL(string: "https://www.reddit.com/r/videos/comments/abc/")!))
    }

    func testParseTime() {
        XCTAssertEqual(LinkParser.parseTime("45"), 45)
        XCTAssertEqual(LinkParser.parseTime("45s"), 45)
        XCTAssertEqual(LinkParser.parseTime("2m"), 120)
        XCTAssertNil(LinkParser.parseTime("abc"))
        XCTAssertNil(LinkParser.parseTime("0"))
    }
}
