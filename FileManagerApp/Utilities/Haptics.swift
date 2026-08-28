import UIKit

/// Haptic feedback wrapper.
///
/// Kept as static generators because creating a `UIImpactFeedbackGenerator`
/// per tap is wasteful and lags on older devices. All calls are main-thread
/// (UI somat) and safely no-ops where unsupported.
enum Haptics {

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    /// Fire on any tactile navigation tap (opening folder, tab switch…).
    static func tap() {
        prepare(light); light.impactOccurred()
    }

    /// Fire on long-presses, drag begin, selection toggles.
    static func tick() {
        prepare(selection); selection.selectionChanged()
    }

    /// Medium weight for entering selection mode / batch actions.
    static func mediumTap() {
        prepare(medium); medium.impactOccurred(intensity: 0.75)
    }

    /// Fire when something destructive is about to happen (delete confirm).
    static func warn() {
        prepare(heavy); heavy.impactOccurred(intensity: 0.9)
    }

    /// Fire on successful heavyweight operations (import, zip, move done).
    static func success() {
        prepare(notification); notification.notificationOccurred(.success)
    }

    /// Fire for failed / blocked operations (rename conflict, auth fail).
    static func error() {
        prepare(notification); notification.notificationOccurred(.error)
    }

    /// Subtle confirmation-less nudge (storage bar tap, info sheet).
    static func softTap() {
        prepare(soft); soft.impactOccurred(intensity: 0.5)
    }

    /// Rim-bite feel for rigid actions (sort apply, structured edits).
    static func rigidTap() {
        prepare(rigid); rigid.impactOccurred(intensity: 0.8)
    }

    private static func prepare(_ g: UIImpactFeedbackGenerator) {
        g.prepare()
    }
    private static func prepare(_ g: UINotificationFeedbackGenerator) {
        g.prepare()
    }
    private static func prepare(_ g: UISelectionFeedbackGenerator) {
        g.prepare()
    }
}