import SwiftUI

/// Central color system. Single source of truth so every screen stays
/// visually consistent without hard-coded hex values sprinkled around.
///
/// Palette (cinematic dark):
///   background #0A0A0C — "Vantablack" base
///   surface     #151517 — cards, sheets
///   elevated    #1C1C1F — raised panels / pressed states
///   text        #F2F2F0 — high continuity off-white
enum Theme {

    // MARK: - Core surfaces / text

    static let background      = Color(hex: 0x0A0A0C)
    static let surface         = Color(hex: 0x151517)
    static let surfaceElevated = Color(hex: 0x1C1C1F)
    static let surfaceStroke   = Color.white.opacity(0.07)

    static let textPrimary   = Color(hex: 0xF2F2F0)
    static let textSecondary = Color(hex: 0xA1A1A8)
    static let textTertiary  = Color(hex: 0x5C5C63)

    // MARK: - Accents (user selectable, default electric blue)

    static let accent = Color(hex: 0x4D8DFF)   // electric blue
    static let accentViolet = Color(hex: 0x8B5CF6)
    static let accentSoft   = Color(hex: 0x4D8DFF).opacity(0.14)

    // MARK: - Semantic

    static let success = Color(hex: 0x34D399)
    static let warning = Color(hex: 0xFBBF24)
    static let danger  = Color(hex: 0xFF5B5B)

    // MARK: - Storage gradient stops (green → yellow → red)
    static let storageClean = Color(hex: 0x34D399)
    static let storageWarm  = Color(hex: 0xFBBF24)
    static let storageHot   = Color(hex: 0xFF5B5B)

    // MARK: - Typography
    // SF Pro Display is the iOS system face; for very heavy weights the
    // system automatically picks Display-style metrics. We expose the two
    // "families" explicitly for clarity.
    enum Font {
        /// Big confident headers (SF Pro Display).
        static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        /// Body / supporting text (SF Pro Text).
        static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .default)
        }
        /// Numeric / mono-ish data (sizes, dates).
        static func mono(_ size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
    }

    // MARK: - Shared visual helpers

    /// Layered depth used for floating chrome (cards above material).
    static func softShadow(radius: CGFloat = 18, y: CGFloat = 8, opacity: Double = 0.35) -> some ViewModifier {
        Modifier.Shadow(radius: radius, y: y, opacity: opacity)
    }

    /// Card chrome: elevated surface + hairline stroke + soft shadow.
    static var cardChrome: some ViewModifier { Modifier.CardChrome() }
}

// MARK: - Reusable modifiers

private enum Modifier {
    struct Shadow: ViewModifier {
        let radius: CGFloat
        let y: CGFloat
        let opacity: Double
        func body(content: Content) -> some View {
            content
                .shadow(color: Color.black.opacity(opacity), radius: radius, x: 0, y: y)
        }
    }

    struct CardChrome: ViewModifier {
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
                )
        }
    }
}

extension Color {
    /// Build a `Color` from a 24-bit hex int, e.g. `Color(hex: 0x0A0A0C)`.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}