import SwiftUI

/// Button label with a one-shot diagonal shine that sweeps across the text and
/// glyph on appear. Shared by the onboarding primary action so the hero button
/// draws the eye once, then rests.
struct ShimmerButtonLabel: View {
    let systemImage: String
    let text: String

    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
        }
        .overlay {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.85), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 72)
                .blendMode(.screen)
                .offset(x: xOffset(geo))
                .animation(.easeInOut(duration: 0.7).delay(0.25), value: shimmer)
            }
            .allowsHitTesting(false)
        }
        .onAppear { shimmer = true }
    }

    private func xOffset(_ geo: GeometryProxy) -> CGFloat {
        shimmer ? geo.size.width + 72 : -72
    }
}

#Preview {
    ShimmerButtonLabel(systemImage: "arrow.right", text: "Next")
        .font(Theme.Font.body(17, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Capsule().fill(Theme.accent))
        .padding(20)
        .background(Theme.background)
}
