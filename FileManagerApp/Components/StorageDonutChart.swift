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

            // Cumulative trim per sector — rotate each to stack them.
            ForEach(cumulativePairs) { pair in
                Circle()
                    .trim(from: pair.start, to: pair.end)
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
        .onAppear {
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