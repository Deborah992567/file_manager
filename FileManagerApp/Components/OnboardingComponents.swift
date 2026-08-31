import SwiftUI

/// Content model for one onboarding slide.
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

/// A single onboarding slide with staggered icon → title → body entrance.
/// Each element waits `delay` before springing in, producing a wave.
struct OnboardingPageCard: View {
    let page: OnboardingPage
    let delay: Double

    @State private var entered = false
    @State private var breathing = false
    @State private var orbiting = false

    var body: some View {
        VStack(spacing: 28) {
            icon
                .modifier(StaggerEntrance(entered: entered, delay: delay))
            title
                .modifier(StaggerEntrance(entered: entered, delay: delay + 0.12))
            subtitle
                .modifier(StaggerEntrance(entered: entered, delay: delay + 0.24))
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(AppMotion.spring) { entered = true }
            withAnimation(AppMotion.ambient.repeatForever(autoreverses: true)) { breathing = true }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { orbiting = true }
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: page.gradient,
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 128, height: 128)
                .blur(radius: 1)
                .overlay {
                    Circle()
                        .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
                }
                // Slow pulse so each page feels alive before the swipe.
                .scaleEffect(breathing ? 1.04 : 0.97)

            // Dashed orbit ring that drips clockwise around the disc.
            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(page.gradient.first?.opacity(0.7) ?? Theme.accent.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [14, 12]))
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(orbiting ? 360 : 0))

            Image(systemName: page.icon)
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
        }
    }

    private var title: some View {
        Text(page.title)
            .font(Theme.Font.display(30, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.center)
    }

    private var subtitle: some View {
        Text(page.subtitle)
            .font(Theme.Font.body(17))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }
}

/// Overshoot-spring entrance with configurable delay.
struct StaggerEntrance: ViewModifier {
    let entered: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(entered ? 1 : 0.8)
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : 14)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78).delay(delay),
                value: entered
            )
    }
}

/// Pagination indicator: the active dot morphs into a wider rounded pill and
/// neighbors shrink — reads as a "sliding" dot row.
struct MorphingDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.accent : Theme.textTertiary.opacity(0.45))
                    .frame(width: i == index ? 24 : 7, height: 7)
                    .animation(AppMotion.spring, value: index)
            }
        }
    }
}

/// Animated gradient backdrop used behind onboarding (parallax-ish glow).
struct AmbientGradientBackground: View {
    let colors: [Color]

    @State private var drift: CGFloat = 0

    var body: some View {
        ZStack {
            Theme.background
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .blur(radius: 70)
                .offset(x: drift, y: -drift * 0.5)
            RadialGradient(colors: [colors.last.map { $0.opacity(0.25) } ?? .clear, .clear],
                           center: .bottomTrailing,
                           startRadius: 10, endRadius: 420)
                .offset(x: -drift * 0.6, y: drift * 0.4)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(AppMotion.ambient.speed(0.5)) { drift = 40 }
        }
    }
}

#Preview {
    OnboardingPageCard(
        page: OnboardingPage(
            icon: "square.grid.2x2",
            title: "Every file, in its place",
            subtitle: "Browse folders in a gorgeous grid or list.",
            gradient: [Theme.accent, Theme.accentViolet]
        ),
        delay: 0
    )
    .background(Theme.background)
}