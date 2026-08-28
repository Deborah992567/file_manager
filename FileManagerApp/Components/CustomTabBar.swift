import SwiftUI

/// The four top-level destinations. Custom tab bar (not `UITabBar`) so the
/// active state can use a sliding pill and each switch is tactile + springy.
enum AppTab: String, CaseIterable, Identifiable {
    case browse, search, favorites, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse:    return "Files"
        case .search:    return "Search"
        case .favorites: return "Favorites"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .browse:    return "folder"
        case .search:    return "magnifyingglass"
        case .favorites: return "star"
        case .settings:  return "gearshape"
        }
    }

    var activeIcon: String {
        switch self {
        case .browse:    return "folder.fill"
        case .search:    return "magnifyingglass"
        case .favorites: return "star.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

/// Animated tab bar with a matched-geometry active pill.
///
/// The pill's frame morphs smoothly between the selected item via
/// `matchedGeometryEffect` — the default `.spring(response: 0.4,
/// dampingFraction: 0.8)` controls the glide, so the indicator "settles"
/// rather than snapping.
struct CustomTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabItem(tab: tab, isActive: tab == selection, namespace: pillNamespace) {
                    Haptics.tap()
                    withAnimation(AppMotion.spring) { selection = tab }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
    }
}

private struct TabItem: View {
    let tab: AppTab
    let isActive: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Theme.accentSoft)
                            .matchedGeometryEffect(id: "tabpill", in: namespace)
                            .frame(width: 46, height: 34)
                    }
                    Image(systemName: isActive ? tab.activeIcon : tab.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
                        .scaleEffect(isActive ? 1.08 : 1)
                }
                .frame(height: 34)

                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityHint("Double-tap to switch to \(tab.title)")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}