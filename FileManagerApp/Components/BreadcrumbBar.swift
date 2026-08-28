import SwiftUI

/// Horizontal breadcrumb trail with animated slide transitions and
/// tap-any-crumb-to-jump. Each crumb is a capsule pill; the current folder is
/// highlighted. Scrolls horizontally if the path gets long.
struct BreadcrumbBar: View {
    let crumbs: [FolderNode]
    let onSelect: (Int) -> Void

    /// Arrow + text capsule for one level. Uses `.id` so SwiftUI treats each
    /// transition as insert/remove → the slide reads as "pushing forward".
    private var styledCrumbs: [(node: FolderNode, title: String)] {
        crumbs.enumerated().map { index, node in
            let title = index == 0 ? "Home" : node.name
            return (node, title)
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(styledCrumbs.enumerated()), id: \.element.node.id) { index, crumb in
                    HStack(spacing: 8) {
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        crumbButton(crumb.node, title: crumb.title, isLast: index == crumbs.count - 1) {
                            Haptics.tick()
                            onSelect(index)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func crumbButton(_ node: FolderNode, title: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: node.kind == .directory || node.kind == .locked ? "folder.fill" : "clock.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isLast ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isLast ? Theme.accentSoft : Theme.surfaceElevated)
            )
            .overlay(
                Capsule().strokeBorder(isLast ? Theme.accent.opacity(0.4) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(QuietButtonStyle())
    }
}