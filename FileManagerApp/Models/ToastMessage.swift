import SwiftUI

/// Transient, non-blocking message shown in the global toast host.
/// Carries an optional trailing action (e.g. "Undo" after a delete) so
/// destructive operations remain recoverable.
struct ToastMessage: Identifiable {
    enum Style {
        case info, success, warning, error
    }

    let id = UUID()
    let icon: String
    let title: String
    var subtitle: String? = nil
    var style: Style = .info
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    // MARK: - Factories

    static func success(_ title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) -> ToastMessage {
        ToastMessage(icon: "checkmark.circle.fill", title: title, subtitle: subtitle, style: .success, actionTitle: actionTitle, action: action)
    }

    static func info(_ title: String, subtitle: String? = nil) -> ToastMessage {
        ToastMessage(icon: "info.circle.fill", title: title, subtitle: subtitle, style: .info)
    }

    static func warning(_ title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) -> ToastMessage {
        ToastMessage(icon: "exclamationmark.triangle.fill", title: title, subtitle: subtitle, style: .warning, actionTitle: actionTitle, action: action)
    }

    static func error(_ title: String, subtitle: String? = nil) -> ToastMessage {
        ToastMessage(icon: "xmark.octagon.fill", title: title, subtitle: subtitle, style: .error)
    }

    // MARK: - Presentation color

    var accentColor: Color {
        switch style {
        case .info:    return Theme.accent
        case .success: return Theme.success
        case .warning: return Theme.warning
        case .error:   return Theme.danger
        }
    }
}