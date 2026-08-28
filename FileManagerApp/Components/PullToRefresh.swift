import SwiftUI

/// Pull-to-refresh with a fully custom indicator (not `UIRefreshControl`).
///
/// How it works:
///  - The scroll content's top edge is tracked via a `GeometryReader`
///    preference in a named coordinate space.
///  - Pulling down grows `pulling`; the floating ring fills up 1:1 with how
///    far you've pulled.
///  - Releasing past the threshold spins the ring and runs `onRefresh`.
///  Tuning knobs: `threshold` and the ring's `.spring` snap-back below.
struct PullToRefresh<Content: View>: View {

    private let content: Content
    private let onRefresh: () async -> Void
    private let threshold: CGFloat = 78

    @State private var pulling: CGFloat = 0
    @State private var isRefreshing = false
    @State private var baseline: CGFloat?

    init(onRefresh: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                content
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: PullOffsetKey.self,
                                value: geo.frame(in: .named("pullScroll")).minY
                            )
                        }
                    )
            }
            .scrollBounceBehavior(.always)  // allow bounce even for short lists
            .onPreferenceChange(PullOffsetKey.self) { minY in
                guard !isRefreshing else { return }
                if baseline == nil { baseline = minY }
                guard let base = baseline else { return }
                pulling = max(0, minY - base)
            }

            RefreshRing(progress: min(1, pulling / threshold), refreshing: isRefreshing)
                .padding(.top, 8)
                .opacity(isRefreshing ? 1 : min(1, pulling / (threshold * 0.6)))
                .offset(y: isRefreshing ? 70 : pulling)
                .allowsHitTesting(false)
                .animation(AppMotion.quick, value: pulling)
        }
        .coordinateSpace(name: "pullScroll")
        .simultaneousGesture(
            DragGesture()
                .onEnded { _ in
                    if !isRefreshing && pulling >= threshold {
                        startRefresh()
                    }
                }
        )
    }

    private func startRefresh() {
        isRefreshing = true
        Haptics.softTap()
        Task {
            await onRefresh()
            // Reset measurement after the reload so a shorter list re-baselines.
            baseline = nil
            withAnimation(AppMotion.spring) {
                isRefreshing = false
                pulling = 0
            }
        }
    }
}

/// Coordinate shim between the scroll geometry and the view state.
private struct PullOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// The animated fill/spin ring.
struct RefreshRing: View {
    let progress: CGFloat
    let refreshing: Bool

    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceElevated, lineWidth: 3)
                .frame(width: 34, height: 34)

            Circle()
                .trim(from: 0, to: refreshing ? 0.75 : progress)
                .stroke(
                    Theme.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(
                    refreshing
                        ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                        : .spring(response: 0.3, dampingFraction: 0.8),
                    value: spinning
                )
                .onAppear {
                    if refreshing { spinning = true }
                }
                .onChange(of: refreshing) { _, isOn in
                    spinning = isOn
                }
        }
        .frame(width: 44, height: 44)
        .background(Circle().fill(Theme.surface))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}