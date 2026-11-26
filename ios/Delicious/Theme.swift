import DeliciousCore
import SwiftUI

/// Visual language: pure black, white type, frosted-glass controls, big white pill buttons.
enum Theme {
    static let background = Color.black
    static let card = Color(white: 0.07)
    static let raised = Color.white.opacity(0.06)
    static let hairline = Color.white.opacity(0.09)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.42)

    static let keep = Color(red: 0.25, green: 0.87, blue: 0.60)
    static let done = Color(red: 1.0, green: 0.38, blue: 0.38)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.29)

    /// Smallest comfortable touch target.
    static let touch: CGFloat = 48
}

// MARK: - Text styles

extension View {
    /// Small uppercase label with wide letter spacing ("SAVE · WATCH").
    func eyebrow() -> some View {
        font(.system(size: 13, weight: .semibold))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.tertiary)
    }
}

// MARK: - Buttons

struct PrimaryPillStyle: ButtonStyle {
    var height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        PrimaryPill(configuration: configuration, height: height)
    }

    private struct PrimaryPill: View {
        let configuration: ButtonStyle.Configuration
        let height: CGFloat
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Capsule().fill(.white))
                .shadow(color: .white.opacity(isEnabled ? 0.25 : 0), radius: 18, y: 6)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

struct GlassPillStyle: ButtonStyle {
    var height: CGFloat = 54
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 16)
            .background(Capsule().fill(Theme.raised))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct GlassCircleStyle: ButtonStyle {
    var size: CGFloat = 56
    var tint: Color = .white
    var filled: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        GlassCircle(configuration: configuration, size: size, tint: tint, filled: filled)
    }

    private struct GlassCircle: View {
        let configuration: ButtonStyle.Configuration
        let size: CGFloat
        let tint: Color
        let filled: Color?
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(filled ?? Theme.raised))
                .overlay(Circle().stroke(filled == nil ? Theme.hairline : tint.opacity(0.35), lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.35)
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
                .contentShape(Circle())
        }
    }
}

// MARK: - Pieces

struct Logo: View {
    var body: some View {
        Text("DELICIOUS")
            .font(.system(size: 21, weight: .black).width(.compressed))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(.white))
            .accessibilityLabel("delicious")
            .accessibilityAddTraits(.isHeader)
    }
}

struct ProviderBadge: View {
    let provider: Provider
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: provider.symbolName)
                .font(.system(size: compact ? 11 : 13, weight: .bold))
            Text(provider.displayName)
                .font(.system(size: compact ? 12 : 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 9 : 12)
        .frame(height: compact ? 26 : 32)
        .background(Capsule().fill(.black.opacity(0.55)))
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text("#\(text)")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Theme.raised))
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }
}

/// Slow drifting colour glow used behind empty states.
struct AuroraBackdrop: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.black
            Circle()
                .fill(Color(red: 1.0, green: 0.36, blue: 0.27).opacity(0.55))
                .frame(width: 420, height: 420)
                .offset(x: drift ? -120 : -60, y: drift ? 260 : 200)
            Circle()
                .fill(Theme.gold.opacity(0.45))
                .frame(width: 360, height: 360)
                .offset(x: drift ? 150 : 90, y: drift ? -260 : -200)
        }
        .blur(radius: 90)
        .overlay(LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

extension VideoLink {
    var formattedDuration: String? {
        guard let duration, duration > 0 else { return nil }
        let total = Int(duration.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
