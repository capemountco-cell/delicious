import DeliciousCore
import SwiftUI
import UIKit

struct AddLinkSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var message: String?
    @FocusState private var focused: Bool
    /// Only checks *whether* the clipboard holds a link — this does not read it or trigger a paste prompt.
    @State private var clipboardHasLink = UIPasteboard.general.hasURLs

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("New video").eyebrow()
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(GlassCircleStyle(size: Theme.touch))
                    .accessibilityLabel("Close")
            }

            Text("Paste a video link")
                .font(.system(size: 30, weight: .bold))

            if clipboardHasLink {
                PasteButton(payloadType: String.self) { strings in
                    guard let first = strings.first else { return }
                    Task { @MainActor in
                        text = first
                        save()
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.white)
                .frame(maxWidth: .infinity)
            }

            TextField("https://…", text: $text, axis: .vertical)
                .font(.system(size: 17))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(minHeight: 58)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.raised))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                .onSubmit(save)
                .onChange(of: text) { message = nil }

            if let message {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.gold)
            }

            Text("Works with YouTube, X, TikTok, Instagram, Vimeo, Facebook, Reddit, Twitch, Loom, Streamable, Dailymotion and direct video files.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Save video", action: save)
                .buttonStyle(PrimaryPillStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Color(white: 0.06))
        .onAppear { if !clipboardHasLink { focused = true } }
    }

    private func save() {
        switch model.add(text) {
        case .added:
            dismiss()
        case .duplicate(let existing):
            message = "Already saved — “\(existing.displayTitle)”."
        case .invalid:
            message = "That doesn’t look like a link. Copy the video’s share link and try again."
        }
    }
}
