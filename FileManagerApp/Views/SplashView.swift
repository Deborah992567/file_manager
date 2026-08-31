import SwiftUI

/// Cinematic splash: logo scales in while a blur dissolves to sharp focus,
/// an ambient glow pulses, a scan-line sweeps the mark and the wordmark
/// staggers in underneath. Then routes to onboarding (first launch) or home
/// (returning) via `AppState`.
struct SplashView: View {
    @Environment(AppState.self) private var appState

    @State private var entered = false
    @State private var settled = false
    @State private var glowing = false
    @State private var scanning = false
    @State private var showingWordmark = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            AmbientGradientBackground(colors: [Theme.accent.opacity(0.55), Theme.accentViolet.opacity(0.4)])

            VStack(spacing: 24) {
                logo
                    .modifier(StaggerEntrance(entered: entered, delay: 0))

                VStack(spacing: 6) {
                    Text("Nova Files")
                        .font(Theme.Font.display(34, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .modifier(StaggerEntrance(entered: showingWordmark, delay: 0))

                    Text("Your files, beautifully organized.")
                        .font(Theme.Font.body(16))
                        .foregroundStyle(Theme.textSecondary)
                        .modifier(StaggerEntrance(entered: showingWordmark, delay: 0.18))

                    shimmerLine
                        .modifier(StaggerEntrance(entered: showingWordmark, delay: 0.34))
                        .padding(.top, 4)
                }
            }
        }
        .onAppear {
            withAnimation(AppMotion.spring) { entered = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.25)) { settled = true }
            withAnimation(AppMotion.ambient) { glowing = true }
            withAnimation(.easeOut(duration: 1.0).delay(0.45)) { scanning = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.55)) { showingWordmark = true }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false).delay(1.3)) { shimmer = true }
        }
        .task {
            // Crossfade into the correct next screen after the entrance reads.
            try? await Task.sleep(nanoseconds: 1_950_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(AppMotion.contentSwap) { appState.launchCompleted() }
        }
    }

    private var logo: some View {
        ZStack {
            // Breathing glow behind the mark — slow ambient loop.
            Circle()
                .fill(Theme.accent)
                .opacity(glowing ? 0.32 : 0.10)
                .frame(width: 150, height: 150)
                .blur(radius: 28)
                .scaleEffect(glowing ? 1.28 : 0.86)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(colors: [Theme.accent, Theme.accentViolet],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .frame(width: 98, height: 98)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .shadow(color: Theme.accent.opacity(0.5), radius: 22, y: 10)
                // Overshoot "settle": a small counter-clockwise wobble that
                // eases back to perfect alignment.
                .rotationEffect(.degrees(settled ? 0 : -7), anchor: .center)

            // Scan-line sweep: thin bright band that travels top → bottom.
            GeometryReader { geo in
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.clear, .white.opacity(0.65), .clear],
                                       startPoint: .top,
                                       endPoint: .bottom)
                    )
                    .frame(width: 110, height: 3)
                    .offset(y: yOffset(for: geo.size.height))
            }
            .frame(width: 130, height: 130)
        }
    }

    /// Thin accent shimmer that sweeps the width of the tagline, then loops.
    private var shimmerLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceElevated)
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(colors: [.clear, Theme.accent.opacity(0.9), .clear],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .frame(width: 46, height: 3)
                    .offset(x: (shimmer ? 1 : -1) * (geo.size.width - 46))
            }
        }
        .frame(width: 120, height: 3)
    }

    private func yOffset(for height: CGFloat) -> CGFloat {
        // Start just above the mark, end just below; only render when scanning.
        let travel = height + 12
        return scanning ? travel : -travel
    }
}