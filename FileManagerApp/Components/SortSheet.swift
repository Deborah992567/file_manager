import SwiftUI

/// Spring-animated sort / view-mode / filter sheet, presented from the
/// browser toolbar. Mutates bindings directly so the browser re-sorts live.
struct SortSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var sortOption: SortOption
    @Binding var sortDirection: SortDirection
    @Binding var viewMode: ViewMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule()
                .fill(Theme.textTertiary.opacity(0.5))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("Sort & View")
                .font(Theme.Font.display(22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            section("View") {
                segmented(viewMode, options: ViewMode.allCases) { mode in
                    Haptics.tick()
                    withAnimation(AppMotion.spring) { viewMode = mode }
                }
            }

            section("Sort by") {
                VStack(spacing: 2) {
                    ForEach(SortOption.allCases) { option in
                        optionRow(
                            label: option.label,
                            icon: option.symbolName,
                            selected: sortOption == option
                        ) {
                            Haptics.tick()
                            withAnimation(AppMotion.quick) { sortOption = option }
                        }
                    }
                }
            }

            section("Direction") {
                HStack(spacing: 10) {
                    directionButton(.ascending)
                    directionButton(.descending)
                }
            }

            Button {
                Haptics.rigidTap()
                dismiss()
            } label: {
                Text("Done")
                    .font(Theme.Font.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressEffectButtonStyle())
        }
        .padding(20)
        .padding(.bottom, 8)
        .presentationDetents([.fraction(0.6)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Reusable rows

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textTertiary)
            content()
        }
    }

    private func segmented(_ selection: ViewMode, options: [ViewMode], onSelect: @escaping (ViewMode) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.symbolName)
                        Text(option.label)
                    }
                    .font(Theme.Font.body(13, weight: .semibold))
                    .foregroundStyle(selection == option ? .white : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(selection == option ? Theme.accent : Theme.surfaceElevated)
                    )
                }
                .buttonStyle(QuietButtonStyle())
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }

    private func optionRow(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 24)

                Text(label)
                    .font(Theme.Font.body(15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func directionButton(_ direction: SortDirection) -> some View {
        Button {
            Haptics.tick()
            withAnimation(AppMotion.quick) { sortDirection = direction }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: direction.symbolName)
                Text(direction.label)
            }
            .font(Theme.Font.body(14, weight: .semibold))
            .foregroundStyle(sortDirection == direction ? .white : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(sortDirection == direction ? Theme.accent : Theme.surfaceElevated))
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityAddTraits(sortDirection == direction ? .isSelected : [])
    }
}

#Preview {
    SortSheet(
        sortOption: .constant(.name),
        sortDirection: .constant(.ascending),
        viewMode: .constant(.grid)
    )
}