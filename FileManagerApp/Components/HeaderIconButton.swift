import SwiftUI

/// Circular icon button for browser chrome (search, sort, new, view toggle).
/// One place owns the size, hit target, accessibility label, haptic hot-path
/// and press feedback so every floaty circle button looks identical.
struct HeaderIconButton: View {
    let icon: String
    let label: String
    var tint: Color? = nil
    var haptic: () -> Void = { Haptics.tap() }
    var action: () -> Void

    init(
        icon: String,
        label: String,
        tint: Color? = nil,
        haptic: @escaping () -> Void = { Haptics.tap() },
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.tint = tint
        self.haptic = haptic
        self.action = action
    }

    var body: some View {
        Button {
            haptic()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint ?? Theme.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.surfaceElevated))
                .accessibilityLabel(label)
        }
        .buttonStyle(PressEffectButtonStyle())
    }
}

#Preview {
    HStack(spacing: 12) {
        HeaderIconButton(icon: "magnifyingglass", label: "Search") {}
        HeaderIconButton(icon: "arrow.up.arrow.down", label: "Sort") {}
        HeaderIconButton(icon: "plus", label: "New", haptic: { Haptics.mediumTap() }) {}
        HeaderIconButton(icon: "square.grid.2x2", label: "Toggle view", haptic: { Haptics.tick() }) {}
    }
    .padding(20)
    .background(Theme.background)
}