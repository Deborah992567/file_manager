import SwiftUI

/// Morphable search input: a glass pill field with a magnifier, live clear
/// button and an optional cancel action. Fits the spec's "search icon morphs
/// into a full-width field" — the parent animates its frame/trailing when it
/// appears.
struct AnimatedSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search files"
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(text.isEmpty ? Theme.textTertiary : Theme.accent)

            TextField(placeholder, text: $text)
                .focused($focused)
                .font(Theme.Font.body(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { onSubmit?() }

            if !text.isEmpty {
                Button {
                    Haptics.tick()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(QuietButtonStyle())
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search")
            }

            if let onCancel {
                Button("Cancel", action: onCancel)
                    .font(Theme.Font.body(15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.5) : Theme.surfaceStroke, lineWidth: 1)
        )
        .animation(AppMotion.spring, value: text.isEmpty)
        .animation(AppMotion.spring, value: focused)
    }
}