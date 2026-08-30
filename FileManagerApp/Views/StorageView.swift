import SwiftUI

/// Storage management: animated donut breakdown by category, device usage
/// summary and a "free up space" action with animated progress.
struct StorageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: SettingsViewModel

    init() {
        _vm = State(initialValue: SettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let snapshot = vm.snapshot {
                        StorageDonutChart(breakdown: snapshot.breakdown)
                            .padding(.top, 20)

                        legend(snapshot)

                        deviceBar(snapshot)

                        freeUpSpaceButton(snapshot)
                    } else {
                        ProgressView()
                            .tint(Theme.accent)
                            .padding(.top, 120)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear { vm.loadUsage() }
        .onChange(of: vm.clearedBytes) { _, bytes in
            guard bytes > 0 else { return }
            appState.showToast(.success("Freed up", subtitle: "\(ByteFormatter.format(bytes)) reclaimed"))
        }
    }

    // MARK: - Sections

    private func legend(_ snapshot: StorageService.Snapshot) -> some View {
        VStack(spacing: 10) {
            ForEach(snapshot.breakdown) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(item.category.color)
                        .frame(width: 10, height: 10)
                    Text(item.category.label)
                        .font(Theme.Font.body(14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(ByteFormatter.format(item.size))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .contentCard()
    }

    private func deviceBar(_ snapshot: StorageService.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Device")
                    .font(Theme.Font.body(13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(snapshot.itemCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            StorageBarView(
                fraction: snapshot.usedFraction,
                freeLabel: "\(ByteFormatter.format(snapshot.free)) free",
                usedLabel: "\(ByteFormatter.format(snapshot.totalUsed)) in Nova Files",
                onTap: {
                    Haptics.softTap()
                    appState.showToast(.info("Storage",
                                             subtitle: "\(snapshot.totalUsed) used · \(snapshot.free) free on this device"))
                }
            )
        }
    }

    private func freeUpSpaceButton(_ snapshot: StorageService.Snapshot) -> some View {
        VStack(spacing: 12) {
            Button {
                Haptics.mediumTap()
                Task { await vm.clearCache() }
            } label: {
                HStack(spacing: 10) {
                    if vm.isClearingCache {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(vm.isClearingCache ? "Freeing space…" : "Free up space")
                        .font(Theme.Font.body(16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressEffectButtonStyle())
            .disabled(vm.isClearingCache)

            Text(vm.clearedBytes > 0
                 ? "Last cleanup reclaimed \(ByteFormatter.format(vm.clearedBytes))."
                 : "Clears trash and temporary files inside Nova Files.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

#Preview {
    StorageView()
        .environment(AppState())
}