import SwiftUI

/// Transient toast card used by the global host. Slide-up from the bottom
/// with a spring settle; carries an optional Undo-style trailing action.
struct ToastView: View {
    let message: ToastMessage

    @State private var entered = false

    var body: some View {
        HStack(spacing: 12) {
            icon
                .modifier(StaggerEntrance(entered: entered, delay: 0.05))

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(Theme.Font.body(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle = message.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle = message.actionTitle {
                Button {
                    Haptics.tap()
                    message.action?()
                } label: {
                    Text(actionTitle)
                        .font(Theme.Font.body(14, weight: .bold))
                        .foregroundStyle(message.accentColor)
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(message.accentColor.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .onAppear {
            withAnimation(AppMotion.spring) { entered = true }
        }
    }

    private var icon: some View {
        Image(systemName: message.icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(message.accentColor)
    }
}

/// Hosts the current toast at the bottom of the screen (above the tab bar).
/// `.id(toastToken)` forces a fresh insert animation even for identical text.
struct ToastHost: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Spacer()
            if let toast = appState.toast {
                ToastView(message: toast)
                    .id(appState.toastToken)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 88)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(AppMotion.spring, value: appState.toastToken)
    }
}

#Preview {
    VStack {
        ToastView(message: .success("Deleted", subtitle: "Report.pdf"))
        ToastView(message: .error("Authentication failed", subtitle: "Try again."))
    }
    .padding(20)
    .background(Theme.background)
}