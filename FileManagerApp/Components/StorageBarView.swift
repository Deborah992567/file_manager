import SwiftUI

/// Animated storage usage bar. The fill animates on first appearance (spring,
/// not a hard cut) and the gradient shifts green → yellow → red by percent.
/// Tap opens the storage breakdown.
struct StorageBarView: View {
    /// 0…1 fraction of capacity in use.
    let fraction: Double
    let freeLabel: String
    let usedLabel: String
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: {
            Haptics.softTap()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Storage")
                        .font(Theme.Font.body(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(freeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                // Track (dark) + animated fill with the temperature gradient.
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surfaceElevated)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.storageClean, Theme.storageWarm, Theme.storageHot],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            // 0.6 → 0.42s spring reads as "charged", tunable below.
                            .frame(width: appeared ? max(8, width * fraction) : 0)
                    }
                }
                .frame(height: 7)

                Text(usedLabel.isEmpty ? "Tap for breakdown" : usedLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .contentCard()
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityHint("Opens the storage breakdown")
        .onAppear {
            // Animate once per appearance; re-show after refresh re-creates.
            guard !appeared else { return }
            withAnimation(AppMotion.spring) { appeared = true }
        }
    }
}

#Preview {
    StorageBarView(fraction: 0.42, freeLabel: "142 GB free", usedLabel: "1.2 GB in Nova Files", onTap: {})
        .padding(16)
        .background(Theme.background)
}