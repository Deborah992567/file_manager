import SwiftUI

/// Animated donut chart for the storage breakdown. Sectors spring in with the
/// shared motion language; the center reads the total used space.
struct StorageDonutChart: View {
    let breakdown: [StorageService.CategoryUsage]

    @State private var appeared = false

    private var total: Int64 {
        breakdown.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceElevated, lineWidth: 20)

            // Cumulative trim per sector — rotate each to stack them. Each
            // sector draws in from zero with a tiny stagger so the donut
            // "races" into place.
            ForEach(cumulativePairs) { pair in
                Circle()
                    .trim(from: pair.start, to: appeared ? pair.end : pair.start)
                    .stroke(
                        pair.usage.category.color,
                        style: StrokeStyle(lineWidth: 20, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 4) {
                Text(ByteFormatter.format(total))
                    .font(Theme.Font.mono(15))
                    .foregroundStyle(Theme.textPrimary)
                Text("used")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 190, height: 190)
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storage used")
        .accessibilityValue(ByteFormatter.format(total))
        .accessibilityHint("\(breakdown.count) categories in the legend below")
        .onAppear {
            // Slight delay so the ring sweeps, not pops.
            withAnimation(AppMotion.spring.delay(0.1)) { appeared = true }
        }
    }

    private struct Pair: Identifiable {
        let id = UUID()
        let usage: StorageService.CategoryUsage
        let start: CGFloat
        let end: CGFloat
    }

    private var cumulativePairs: [Pair] {
        let denominator = max(1, total)
        var running: Double = 0
        return breakdown.filter { $0.size > 0 }.map { usage in
            let start = running
            let end = min(1, running + Double(usage.size) / Double(denominator))
            running = end
            return Pair(usage: usage, start: start, end: end)
        }
    }
}

#Preview {
    StorageDonutChart(breakdown: [
        StorageService.CategoryUsage(category: .documents, size: 512_000_000),
        StorageService.CategoryUsage(category: .media, size: 1_200_000_000),
        StorageService.CategoryUsage(category: .downloads, size: 84_000_000),
        StorageService.CategoryUsage(category: .other, size: 3_200_000),
    ])
    .padding(24)
    .background(Theme.background)
}