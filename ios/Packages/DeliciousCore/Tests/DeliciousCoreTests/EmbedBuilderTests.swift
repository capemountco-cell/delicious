import XCTest
@testable import DeliciousCore

final class EmbedBuilderTests: XCTestCase {
    private func link(_ s: String) -> VideoLink {
        let url = URL(string: s)!
        return VideoLink(parsed: LinkParser.parse(url), originalURL: url)
    }

    private func embed(_ s: String) -> String? { EmbedBuilder.embedURL(for: link(s))?.absoluteString }

    func testYouTubeEmbedPlaysInline() {
        XCTAssertEqual(embed("https://youtu.be/dQw4w9WgXcQ"), "https://www.youtube.com/embed/dQw4w9WgXcQ?playsinline=1&rel=0&modestbranding=1")
        XCTAssertEqual(embed("https://youtu.be/dQw4w9WgXcQ?t=42"), "https://www.youtube.com/embed/dQw4w9WgXcQ?playsinline=1&rel=0&modestbranding=1&start=42")
    }

    func testProviderEmbeds() {
        XCTAssertEqual(embed("https://x.com/a/status/99"), "https://platform.twitter.com/embed/Tweet.html?id=99&theme=dark&dnt=true")
        XCTAssertEqual(embed("https://www.tiktok.com/@a/video/123"), "https://www.tiktok.com/player/v1/123?description=1&music_info=1&rel=0")
        XCTAssertEqual(embed("https://www.instagram.com/reel/ABC/"), "https://www.instagram.com/reel/ABC/embed/")
        XCTAssertEqual(embed("https://vimeo.com/76979871/abcdef1234"), "https://player.vimeo.com/video/76979871?playsinline=1&dnt=1&h=abcdef1234")
        XCTAssertEqual(embed("https://dai.ly/x8abc12"), "https://www.dailymotion.com/embed/video/x8abc12")
        XCTAssertEqual(embed("https://www.loom.com/share/abc"), "https://www.loom.com/embed/abc")
        XCTAssertEqual(embed("https://streamable.com/moo12"), "https://streamable.com/e/moo12")
        XCTAssertEqual(embed("https://www.reddit.com/r/videos/comments/abc123/funny/?utm=1"), "https://embed.reddit.com/r/videos/comments/abc123/funny/")
        XCTAssertEqual(embed("https://clips.twitch.tv/Slug"), "https://clips.twitch.tv/embed?clip=Slug&parent=com.capemount.delicious")
        XCTAssertEqual(
            embed("https://www.facebook.com/a/videos/1/"),
            "https://www.facebook.com/plugins/video.php?href=https%3A%2F%2Fwww.facebook.com%2Fa%2Fvideos%2F1%2F&show_text=false"
        )
    }

    func testSourcesByKind() {
        XCTAssertEqual(EmbedBuilder.source(for: link("https://cdn.example.com/a.mp4")), .native(URL(string: "https://cdn.example.com/a.mp4")!))
        XCTAssertEqual(EmbedBuilder.source(for: link("https://example.com/page")), .page(URL(string: "https://example.com/page")!))
        // Short TikTok link without an id yet: fall back to the page itself.
        XCTAssertEqual(EmbedBuilder.source(for: link("https://vm.tiktok.com/ZMabc/")), .page(URL(string: "https://vm.tiktok.com/ZMabc/")!))
        guard case let .embed(src, html, base) = EmbedBuilder.source(for: link("https://youtu.be/dQw4w9WgXcQ")) else {
            return XCTFail("expected embed")
        }
        XCTAssertEqual(base, EmbedBuilder.appOrigin)
        XCTAssertTrue(html.contains("src=\"https://www.youtube.com/embed/dQw4w9WgXcQ?playsinline=1&amp;rel=0&amp;modestbranding=1\""))
        XCTAssertTrue(html.contains("allowfullscreen"))
        XCTAssertEqual(src.host, "www.youtube.com")
    }

    func testWrapperEscapesQuotes() {
        let html = EmbedBuilder.wrapperHTML(src: URL(string: "https://example.com/?a=%22x%22&b=<")!)
        XCTAssertFalse(html.contains("b=<"))
    }
}
