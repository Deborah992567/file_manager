import SwiftUI

// MARK: - Press effect

/// Button style used by every tappable surface that needs press feedback.
/// Scales down under touch and springs back — tuned via `AppMotion.quick`.
struct PressEffectButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96
    var pressedOpacity: Double = 0.88

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1, anchor: .center)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            // Shift then spring back for a tactile, physical feel.
            .animation(AppMotion.quick, value: configuration.isPressed)
    }
}

extension View {
    func pressEffect(scale: CGFloat = 0.96, opacity: Double = 0.88) -> some View {
        buttonStyle(PressEffectButtonStyle(pressedScale: scale, pressedOpacity: opacity))
    }

    /// Dimmed backdrop behind modal layers / sheets.
    @ViewBuilder
    func dimBackdrop(isVisible: Bool) -> some View {
        overlay {
            if isVisible {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.contentSwap, value: isVisible)
    }

    /// Ultra-thin blur used to float cards above content ("soft depth").
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    /// Core content-card background.
    func contentCard() -> some View {
        modifier(Theme.cardChrome)
    }
}

// MARK: - Collection helpers

extension Collection {
    /// Pair each element with its index (used for staggered entrances).
    var indexed: [(offset: Int, element: Element)] {
        Array(enumerated())
    }
}

// MARK: - Geometry / layout helpers

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}