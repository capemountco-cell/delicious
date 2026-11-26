import AVKit
import DeliciousCore
import SwiftUI
import UIKit
import WebKit

/// Plays a saved video inline: the site's own player, or the native player for video files.
struct PlayerView: View {
    let link: VideoLink

    var body: some View {
        ZStack {
            Color.black
            switch EmbedBuilder.source(for: link) {
            case .native(let url):
                NativePlayer(url: url)
            case .embed(_, let html, let baseURL):
                WebPlayer(content: .html(html, baseURL))
            case .page(let url):
                WebPlayer(content: .url(url))
            }
        }
    }
}

private struct NativePlayer: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil { player = AVPlayer(url: url) }
            }
            .onDisappear { player?.pause() }
    }
}

struct WebPlayer: UIViewRepresentable {
    enum Content: Equatable {
        case html(String, URL)
        case url(URL)
    }

    let content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsBackForwardNavigationGestures = false
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        load(content, into: web, coordinator: context.coordinator)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.loaded != content {
            load(content, into: web, coordinator: context.coordinator)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        // Stops any audio still playing when the card goes away.
        web.stopLoading()
        web.loadHTMLString("", baseURL: nil)
    }

    private func load(_ content: Content, into web: WKWebView, coordinator: Coordinator) {
        coordinator.loaded = content
        switch content {
        case .html(let html, let base):
            coordinator.isWrapper = true
            web.loadHTMLString(html, baseURL: base)
        case .url(let url):
            coordinator.isWrapper = false
            web.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var loaded: Content?
        var isWrapper = false

        // Links that try to open a new window ("Watch on YouTube") open in the real app / Safari.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url { UIApplication.shared.open(url) }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            let scheme = url.scheme?.lowercased() ?? ""
            // App links (youtube://, twitter://…) go to the installed app.
            if !["http", "https", "about", "data", "blob"].contains(scheme) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return .cancel
            }
            // A tap inside an embedded player that would replace the whole page: open outside instead.
            if isWrapper, navigationAction.targetFrame?.isMainFrame == true, navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return .cancel
            }
            return .allow
        }
    }
}

/// Still image for a saved video (remote thumbnail, generated thumbnail, or a tasteful placeholder).
struct Thumbnail: View {
    let link: VideoLink

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.16), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: link.provider.symbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.25))
            if let local = AppModel.localThumbnail(for: link), let image = UIImage(contentsOfFile: local.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = link.thumbnailURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
