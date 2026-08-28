import SwiftUI

/// Central movement language.
///
/// Every animation in the app flows from this single enum so the feel is
/// consistent and, most importantly, *tunable in one place*. Tweak a value
/// below and the whole app picks it up.
enum AppMotion {

    // MARK: Default shared curve
    //
    // .spring(response:dampingFraction:) — the specified default.
    //  - response 0.4s : how long the spring takes to traverse to rest.
    //    Lower = snappier. Keep 0.3–0.5 for the app-wide "confident" feel.
    //  - dampingFraction 0.8 : near-critical damping → settles with a tiny
    //    controlled overshoot instead of wobbling. 0.6–0.85 range.
    static let spring: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    /// Hero / shared-element transitions want a slightly longer response so
    /// the morph reads as intentional rather than mechanical.
    static let hero: Animation = .spring(response: 0.55, dampingFraction: 0.82)

    /// Micro-interactions: button presses, checkmarks, toggles.
    static let quick: Animation = .spring(response: 0.26, dampingFraction: 0.75)

    /// Sheets use interactive physics so they feel direct under the finger.
    static let sheetPhysics = Animation.interactiveSpring(response: 0.4, dampingFraction: 0.86, blendDuration: 0.2)

    /// Gentle fade/slide used for content swaps while navigating.
    static let contentSwap: Animation = .easeInOut(duration: 0.22)

    /// Slow ambient loops (splash glow, empty-state illustration).
    static let ambient: Animation = .easeInOut(duration: 1.6).repeatForever(autoreverses: true)

    /// Configurable variant for list insertions / deletions.
    static func list(insertion: Bool = true) -> Animation {
        .spring(response: insertion ? 0.35 : 0.4, dampingFraction: 0.82)
    }
}