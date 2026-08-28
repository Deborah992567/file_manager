import SwiftUI

/// Friendly empty-state for empty folders or matchless search results.
/// Enters with a spring bounce and a slow ambient float so it feels alive
/// rather than like a dead screen.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @State private var entered = false
    @State private var floating = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                    .frame(width: 108, height: 108)
                    .blur(radius: 2)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Theme.surfaceElevated, Theme.surface],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
            }
            // Slow 1.6 s ambient bob — visual rest, not interaction.
            .offset(y: floating ? -6 : 6)
            .animation(AppMotion.ambient, value: floating)

            Text(title)
                .font(Theme.Font.display(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text(subtitle)
                .font(Theme.Font.body(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text(actionTitle)
                    }
                    .font(Theme.Font.body(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressEffectButtonStyle())
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .scaleEffect(entered ? 1 : 0.9)
        .opacity(entered ? 1 : 0)
        .onAppear {
            withAnimation(AppMotion.spring) { entered = true }
            floating = true
        }
    }
}