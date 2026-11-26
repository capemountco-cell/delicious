import DeliciousCore
import SwiftUI

/// One card in the review stack. The video area is fully interactive (tap to play);
/// the information panel underneath is the swipe handle.
struct VideoCard: View {
    let link: VideoLink
    let isTop: Bool
    @Binding var drag: CGSize
    var onRelease: (CGSize, CGSize) -> Void
    var onExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if isTop {
                        PlayerView(link: link).id(link.id)
                    } else {
                        Thumbnail(link: link)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if isTop {
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(GlassCircleStyle(size: Theme.touch, filled: .black.opacity(0.6)))
                    .padding(12)
                    .accessibilityLabel("Open full screen")
                }
            }
            .frame(maxHeight: .infinity)

            info
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { drag = $0.translation }
                        .onEnded { onRelease($0.translation, $0.predictedEndTranslation) }
                )
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .overlay(alignment: .top) { if isTop { stamps } }
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                ProviderBadge(provider: link.provider, compact: true)
                if let d = link.formattedDuration {
                    Text(d)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Text(link.addedAt, format: .relative(presentation: .named))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.tertiary)
            }

            Text(link.displayTitle)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .redacted(reason: (!link.enriched && link.title == nil && link.sourceTitle == nil) ? .placeholder : [])

            if let author = link.author {
                Text(author)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }

            if !link.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(link.tags, id: \.self) { TagChip(text: $0) }
                }
            }

            if isTop {
                HStack {
                    Label("Done", systemImage: "arrow.left")
                    Spacer()
                    Label("Favorite", systemImage: "arrow.up")
                    Spacer()
                    Label("Keep", systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.tertiary)
                .padding(.top, 2)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
    }

    private var stamps: some View {
        let x = drag.width
        let y = drag.height
        return ZStack {
            stamp("KEEP", color: Theme.keep).opacity(Double(max(0, min(1, x / 90))))
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, alignment: .leading)
            stamp("DONE", color: Theme.done).opacity(Double(max(0, min(1, -x / 90))))
                .rotationEffect(.degrees(12))
                .frame(maxWidth: .infinity, alignment: .trailing)
            stamp("FAVE", color: Theme.gold).opacity(abs(y) > abs(x) ? Double(max(0, min(1, -y / 110))) : 0)
        }
        .padding(28)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .black).width(.compressed))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
