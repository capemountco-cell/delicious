import DeliciousCore
import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: LibraryFilter = .all
    @State private var search = ""
    @State private var selected: VideoLink?
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let items = model.library.filtered(filter, search: search)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                searchField
                chips
                if items.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { link in
                            Button { selected = link } label: { LibraryTile(link: link) }
                                .buttonStyle(TileButtonStyle())
                                .contextMenu { menu(for: link) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .fullScreenCover(item: $selected) { link in
            VideoDetailView(linkID: link.id)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiary)
            TextField("Search your videos", text: $search)
                .font(.system(size: 17))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.tertiary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(minHeight: 52)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", .all)
                chip("Favorites", .favorites, symbol: "star.fill")
                ForEach(model.library.allTags.prefix(12), id: \.self) { tag in
                    chip("#\(tag)", .tag(tag))
                }
                ForEach(model.library.providersInUse, id: \.self) { provider in
                    chip(provider.displayName, .provider(provider), symbol: provider.symbolName)
                }
                chip("Archive", .archived, symbol: "archivebox")
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, _ value: LibraryFilter, symbol: String? = nil) -> some View {
        let isOn = filter == value
        return Button {
            withAnimation(.spring(duration: 0.25)) { filter = value }
        } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isOn ? .black : .white)
            .padding(.horizontal, 16)
            .frame(minHeight: 42)
            .background(Capsule().fill(isOn ? Color.white : Theme.raised))
            .overlay(Capsule().stroke(isOn ? Color.clear : Theme.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .archived ? "archivebox" : "sparkles.tv")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tertiary)
            Text(search.isEmpty ? emptyTitle : "No matches for “\(search)”")
                .font(.system(size: 19, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(search.isEmpty ? emptyHint : "Try a different word.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    private var emptyTitle: String {
        switch filter {
        case .archived: return "Archive is empty"
        case .favorites: return "No favorites yet"
        default: return "Nothing here yet"
        }
    }

    private var emptyHint: String {
        switch filter {
        case .archived: return "Videos you swipe away as done land here."
        case .favorites: return "Swipe a card up or tap the star to favorite it."
        default: return "Videos you keep while reviewing show up here."
        }
    }

    @ViewBuilder
    private func menu(for link: VideoLink) -> some View {
        Button { model.library.toggleFavorite(link.id) } label: {
            Label(link.isFavorite ? "Remove favorite" : "Favorite", systemImage: link.isFavorite ? "star.slash" : "star")
        }
        ShareLink(item: link.url) { Label("Share", systemImage: "square.and.arrow.up") }
        if link.status == .archived {
            Button { model.library.setStatus(link.id, .kept) } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
        } else {
            Button { model.library.setStatus(link.id, .archived) } label: { Label("Archive", systemImage: "archivebox") }
        }
        Button(role: .destructive) { model.library.delete(link.id) } label: { Label("Delete", systemImage: "trash") }
    }
}

struct LibraryTile: View {
    let link: VideoLink

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(Thumbnail(link: link))
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(link.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let author = link.author {
                    Text(author)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .overlay(alignment: .topLeading) {
            ProviderBadge(provider: link.provider, compact: true).padding(10)
        }
        .overlay(alignment: .topTrailing) {
            if link.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.black.opacity(0.6)))
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if link.status == .queued {
                Text("NEW")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(.white))
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.displayTitle), \(link.provider.displayName)\(link.isFavorite ? ", favorite" : "")")
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
