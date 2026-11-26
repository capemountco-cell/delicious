import DeliciousCore
import SwiftUI

/// Full-screen player with everything you can do with a saved video.
struct VideoDetailView: View {
    let linkID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.background.ignoresSafeArea()
                if let link = model.library.item(linkID) {
                    content(link, size: geo.size)
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
        }
    }

    private func content(_ link: VideoLink, size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack {
                ProviderBadge(provider: link.provider)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(GlassCircleStyle(size: Theme.touch))
                    .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            PlayerView(link: link)
                .id(link.id)
                .frame(width: size.width, height: playerHeight(link, size: size))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(link.displayTitle)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    HStack(spacing: 10) {
                        if let author = link.author {
                            Text(author).foregroundStyle(Theme.secondary)
                        }
                        if let d = link.formattedDuration {
                            Text(d).monospacedDigit().foregroundStyle(Theme.tertiary)
                        }
                        Text(link.addedAt, format: .dateTime.day().month(.abbreviated).year())
                            .foregroundStyle(Theme.tertiary)
                    }
                    .font(.system(size: 15, weight: .medium))

                    if !link.tags.isEmpty {
                        HStack(spacing: 6) { ForEach(link.tags, id: \.self) { TagChip(text: $0) } }
                    }

                    actions(link)
                        .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .confirmationDialog("Delete this video?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.library.delete(link.id)
                dismiss()
            }
        } message: {
            Text("It will be removed from delicious. You can still find it on \(link.provider.displayName).")
        }
    }

    private func playerHeight(_ link: VideoLink, size: CGSize) -> CGFloat {
        let natural = size.width / CGFloat(link.aspect.ratio)
        return min(natural, size.height * (link.aspect == .landscape ? 0.5 : 0.62))
    }

    private func actions(_ link: VideoLink) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { model.library.toggleFavorite(link.id) } label: {
                    Label(link.isFavorite ? "Favorited" : "Favorite", systemImage: link.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(GlassPillStyle(tint: link.isFavorite ? Theme.gold : .white))

                ShareLink(item: link.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GlassPillStyle())
            }

            Link(destination: link.url) {
                Label("Open on \(link.provider == .web ? (link.url.host ?? "the web") : link.provider.displayName)", systemImage: "arrow.up.right")
            }
            .buttonStyle(GlassPillStyle())

            HStack(spacing: 10) {
                if link.status == .archived {
                    Button { model.library.setStatus(link.id, .kept) } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(GlassPillStyle())
                } else {
                    Button {
                        model.library.setStatus(link.id, .archived)
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "archivebox")
                    }
                    .buttonStyle(GlassPillStyle())
                }
                if link.status != .queued {
                    Button { model.library.setStatus(link.id, .queued) } label: {
                        Label("Review again", systemImage: "rectangle.stack")
                    }
                    .buttonStyle(GlassPillStyle())
                }
            }

            Button { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(GlassPillStyle(tint: Theme.done))
        }
    }
}
