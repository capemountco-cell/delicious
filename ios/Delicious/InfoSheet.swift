import SwiftUI

/// How it works + plain-language privacy.
struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    Logo()
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(GlassCircleStyle(size: Theme.touch))
                        .accessibilityLabel("Close")
                }

                section("How it works", items: [
                    ("plus.circle.fill", "Save", "Tap + and paste a link from YouTube, X, TikTok, Instagram and other video sites."),
                    ("rectangle.stack.fill", "Review", "New videos wait in a stack. Watch right on the card, then swipe: right to keep, left when you’re done, up to favorite."),
                    ("square.grid.2x2.fill", "Library", "Everything you kept, searchable and sorted by topic and site. Done videos stay in the archive."),
                ])

                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy").eyebrow()
                    privacyRow("Your library stays on this phone.", "There’s no account. Saved links, favorites and history are stored only on your device and are removed if you delete the app.")
                    privacyRow("Video details come from the video’s site.", "When you save a link, the app asks the site it came from (for example YouTube or X) for the public title, channel and thumbnail.")
                    privacyRow("Tidy titles and topics.", "The link and its public title are sent to the delicious server, which returns a cleaner title and a few topic tags. Nothing else about you is sent, and nothing is kept for advertising.")
                    privacyRow("Playback happens on the original site.", "Videos play in the site’s own player, so that site may see your visit and use cookies under its own privacy policy.")
                }

                Text("Tip: in Shortcuts, open the URL delicious://add?url=… to save a link straight from the share sheet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Color(white: 0.06))
    }

    private struct Step: Identifiable {
        let symbol: String
        let heading: String
        let detail: String
        var id: String { heading }
    }

    private func section(_ title: String, items: [(String, String, String)]) -> some View {
        let steps = items.map { Step(symbol: $0.0, heading: $0.1, detail: $0.2) }
        return VStack(alignment: .leading, spacing: 16) {
            Text(title).eyebrow()
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.raised))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.heading).font(.system(size: 17, weight: .semibold))
                        Text(step.detail).font(.system(size: 15)).foregroundStyle(Theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func privacyRow(_ heading: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading).font(.system(size: 17, weight: .semibold))
            Text(detail).font(.system(size: 15)).foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.raised))
    }
}
