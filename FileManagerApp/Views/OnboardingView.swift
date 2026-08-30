import SwiftUI

/// Swipeable 4-page onboarding with staggered entrances, morphing dots and a
/// permission-rationale card before the app hands off to the browser.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    @State private var page = 0
    @State private var showPermissionCard = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "square.grid.2x2",
            title: "Every file, in its place",
            subtitle: "Browse folders in a gorgeous grid or list, jump between locations and keep everything at your fingertips.",
            gradient: [Color(hex: 0x4D8DFF), Color(hex: 0x22D3EE)]
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            title: "Search that keeps up",
            subtitle: "Live results as you type — grouped by type, filtered by size or date, with your recent searches remembered.",
            gradient: [Color(hex: 0x8B5CF6), Color(hex: 0x60A5FA)]
        ),
        OnboardingPage(
            icon: "lock.shield",
            title: "Secure by design",
            subtitle: "Face ID guards your whole app and the private Locked Folder keeps sensitive files out of sight.",
            gradient: [Color(hex: 0xA855F7), Color(hex: 0x6366F1)]
        ),
        OnboardingPage(
            icon: "bolt.circle",
            title: "Quick actions, done",
            subtitle: "Zip, share, move, tag colors and drag-and-drop — powerful operations that feel effortless.",
            gradient: [Color(hex: 0x34D399), Color(hex: 0x4D8DFF)]
        ),
    ]

    var body: some View {
        ZStack {
            // Parallax-ish background: hue follows the visible page.
            AmbientGradientBackground(colors: pages[page].gradient)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        Haptics.tap()
                        appState.finishOnboarding()
                    }
                    .font(Theme.Font.body(14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.trailing, 20)
                    .padding(.top, 12)
                }

                TabView(selection: $page) {
                    ForEach(pages.indexed, id: \.element.id) { index, p in
                        OnboardingPageCard(page: p, delay: Double(index) * 0.06)
                            .tag(index)
                            .padding(.bottom, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .bottom) { pageIndicator }
                .padding(.top, 28)

                getStarted
                    .padding(.bottom, 26)
            }
        }
        .overlay {
            if showPermissionCard {
                PermissionRationaleCard(
                    onAllow: {
                        Haptics.success()
                        withAnimation(AppMotion.spring) { showPermissionCard = false }
                        appState.finishOnboarding()
                    },
                    onDismiss: {
                        Haptics.tick()
                        withAnimation(AppMotion.spring) { showPermissionCard = false }
                        appState.finishOnboarding()
                    }
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(AppMotion.spring, value: showPermissionCard)
    }

    // MARK: - Subviews

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            MorphingDots(count: pages.count, index: page)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .allowsHitTesting(false)
    }

    private var getStarted: some View {
        Button {
            Haptics.mediumTap()
            if page == pages.count - 1 {
                withAnimation(AppMotion.spring) { showPermissionCard = true }
            } else {
                withAnimation(AppMotion.spring) { page += 1 }
            }
        } label: {
            HStack(spacing: 8) {
                Text(page == pages.count - 1 ? "Get Started" : "Next")
                Image(systemName: page == pages.count - 1 ? "sparkles" : "arrow.right")
            }
            .font(Theme.Font.body(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Theme.accent))
            .padding(.horizontal, 24)
        }
        .buttonStyle(PressEffectButtonStyle())
    }
}

/// Clear rationale before any system permission prompt can fire.
struct PermissionRationaleCard: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.accentSoft))

                Text("Why we ask for access")
                    .font(Theme.Font.display(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                VStack(alignment: .leading, spacing: 10) {
                    rationaleRow("Files", subtitle: "Import documents and folders from the Files app into Nova Files.")
                    rationaleRow("Photos", subtitle: "Copy photos from your library into any folder, when you choose.")
                }

                Text("Nothing is accessed without your choice — you pick each file.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)

                Button(action: onAllow) {
                    Text("Continue")
                        .font(Theme.Font.body(16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(PressEffectButtonStyle())
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
        }
    }

    private func rationaleRow(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.success)
                .frame(width: 7, height: 7)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.body(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}