import DeliciousCore
import SwiftUI

/// Swipe through newly saved videos, one card at a time. The top card plays inline.
struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var committing = false
    @State private var expanded: VideoLink?

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        let queue = model.library.queue
        VStack(spacing: 14) {
            if queue.isEmpty {
                CaughtUpView()
            } else {
                ZStack {
                    ForEach(Array(queue.prefix(3).enumerated()).reversed(), id: \.element.id) { index, link in
                        let isTop = index == 0
                        VideoCard(
                            link: link,
                            isTop: isTop,
                            drag: isTop ? $drag : .constant(.zero),
                            onRelease: { translation, predicted in release(link, translation, predicted) },
                            onExpand: { expanded = link }
                        )
                        .scaleEffect(isTop ? 1 : 1 - CGFloat(index) * 0.045, anchor: .bottom)
                        .offset(y: isTop ? 0 : CGFloat(index) * 12)
                        .offset(isTop ? drag : .zero)
                        .rotationEffect(.degrees(isTop ? Double(drag.width / 22) : 0), anchor: .bottom)
                        .allowsHitTesting(isTop && !committing)
                        .zIndex(Double(3 - index))
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)

                controls(for: queue.first)
            }
        }
        .fullScreenCover(item: $expanded) { link in
            VideoDetailView(linkID: link.id)
        }
    }

    // MARK: - Controls

    private func controls(for link: VideoLink?) -> some View {
        HStack(spacing: 10) {
            Button { withAnimation(.spring(duration: 0.35)) { model.undo() } } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(GlassCircleStyle(size: 56))
            .disabled(!model.library.canUndo || committing)
            .accessibilityLabel("Undo")

            Button { if let link { commit(.archive, link) } } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(GlassCircleStyle(size: 56, tint: Theme.done))
            .accessibilityLabel("Done — move to archive")

            Button { if let link { commit(.keep, link) } } label: {
                Label("Keep", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PrimaryPillStyle(height: 56))
            .accessibilityLabel("Keep in library")

            Button { if let link { commit(.favorite, link) } } label: {
                Image(systemName: "star.fill")
            }
            .buttonStyle(GlassCircleStyle(size: 56, tint: Theme.gold))
            .accessibilityLabel("Favorite")
        }
        .disabled(link == nil)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(.black.opacity(0.55)))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Swiping

    private func release(_ link: VideoLink, _ translation: CGSize, _ predicted: CGSize) {
        let x = abs(predicted.width) > abs(translation.width) * 2.5 ? predicted.width / 2 : translation.width
        let y = abs(predicted.height) > abs(translation.height) * 2.5 ? predicted.height / 2 : translation.height
        if y < -swipeThreshold * 1.2, abs(y) > abs(x) {
            commit(.favorite, link)
        } else if x > swipeThreshold {
            commit(.keep, link)
        } else if x < -swipeThreshold {
            commit(.archive, link)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { drag = .zero }
        }
    }

    private func commit(_ decision: Decision, _ link: VideoLink) {
        guard !committing else { return }
        committing = true
        let target: CGSize
        switch decision {
        case .keep: target = CGSize(width: 700, height: drag.height + 40)
        case .archive: target = CGSize(width: -700, height: drag.height + 40)
        case .favorite: target = CGSize(width: drag.width, height: -1100)
        }
        withAnimation(.easeIn(duration: 0.22)) { drag = target }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 230_000_000)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                model.decide(link.id, decision)
                drag = .zero
            }
            committing = false
        }
    }
}

/// Shown when every saved video has been reviewed.
private struct CaughtUpView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.keep)
                .padding(.bottom, 18)
            Text("Nothing to review").eyebrow()
                .padding(.bottom, 10)
            (Text("All caught up.\n") + Text("Save something new.").foregroundStyle(Theme.tertiary))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            VStack(spacing: 12) {
                Button("Add a video") { model.showAdd = true }
                    .buttonStyle(PrimaryPillStyle())
                Button("Open library") {
                    withAnimation(.spring(duration: 0.3)) { model.tab = .library }
                }
                .buttonStyle(GlassPillStyle(height: 56))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
