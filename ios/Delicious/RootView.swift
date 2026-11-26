import DeliciousCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            Theme.background.ignoresSafeArea()
            if model.library.isEmpty {
                WelcomeView()
            } else {
                VStack(spacing: 14) {
                    header
                    TabSwitcher(selection: $model.tab, reviewCount: model.library.queue.count)
                        .padding(.horizontal, 16)
                    Group {
                        switch model.tab {
                        case .review: ReviewView()
                        case .library: LibraryView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $model.showAdd) { AddLinkSheet() }
        .sheet(isPresented: $model.showInfo) { InfoSheet() }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.decisionCount)
    }

    private var header: some View {
        HStack {
            Logo()
            Spacer()
            Button { model.showInfo = true } label: {
                Image(systemName: "info")
            }
            .buttonStyle(GlassCircleStyle(size: Theme.touch))
            .accessibilityLabel("How it works and privacy")
            Button { model.showAdd = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(GlassCircleStyle(size: Theme.touch, tint: .black, filled: .white))
            .accessibilityLabel("Add a video")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

/// Big two-way switch between the review stack and the library.
struct TabSwitcher: View {
    @Binding var selection: AppTab
    let reviewCount: Int
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            segment(.review, title: "Review", count: reviewCount)
            segment(.library, title: "Library", count: nil)
        }
        .padding(4)
        .background(Capsule().fill(Theme.raised))
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }

    private func segment(_ tab: AppTab, title: String, count: Int?) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(.spring(duration: 0.3)) { selection = tab }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 7)
                        .frame(minWidth: 24, minHeight: 22)
                        .background(Capsule().fill(selected ? Color.black : Color.white.opacity(0.15)))
                        .foregroundStyle(.white)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(selected ? .black : Theme.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if selected {
                    Capsule().fill(.white).matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// First-run screen.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            AuroraBackdrop()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Logo()
                    Spacer()
                }
                Spacer()
                Text("Save · Watch · No tabs").eyebrow()
                    .padding(.bottom, 14)
                (Text("Every video you love,\nin one place.\n") + Text("Played right here.").foregroundStyle(Theme.tertiary))
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Paste a link from YouTube, X, TikTok, Instagram and more. Swipe through what you saved and watch it inline — no app hopping.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondary)
                    .lineSpacing(3)
                    .padding(.top, 16)
                Spacer().frame(height: 36)
                Button("Add your first video") { model.showAdd = true }
                    .buttonStyle(PrimaryPillStyle())
                HStack(spacing: 8) {
                    Spacer()
                    Button("How it works & privacy") { model.showInfo = true }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .frame(minHeight: Theme.touch)
                    Spacer()
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}
