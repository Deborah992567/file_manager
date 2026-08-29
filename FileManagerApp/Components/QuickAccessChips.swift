import SwiftUI

/// Horizontal strip of quick-access locations (Recents, Favorites, Downloads,
/// On My iPhone, Locked Folder). Tapping one opens that node in the browser.
struct QuickAccessChips: View {
    let currentNode: FolderNode?
    let onSelect: (FolderNode) -> Void
    let onLockedFolder: () -> Void

    private var chips: [(icon: String, label: String, node: FolderNode)] {
        [
            ("iphone", "On My iPhone", FolderNode.directory(FileService.shared.rootURL, named: "On My iPhone")),
            ("clock.fill", "Recents", .recents),
            ("star.fill", "Favorites", .favorites),
            ("arrow.down.circle.fill", "Downloads", FolderNode.directory(FileService.shared.downloadsURL)),
        ]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                let hasLocked = FileService.shared.hasLockedFolder
                let lockedChip = ("lock.fill", "Locked", FolderNode.locked(FileService.shared.lockedFolderURL))

                // Inline "locked" chip so it only renders when it exists.
                let all = hasLocked ? chips + [lockedChip] : chips

                ForEach(Array(all.enumerated()), id: \.element.node.id) { _, chip in
                    if chip.label == "Locked" {
                        lockedChipView(icon: chip.icon, label: chip.label)
                    } else {
                        chipButton(icon: chip.icon, label: chip.label, node: chip.node)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func chipButton(icon: String, label: String, node: FolderNode) -> some View {
        let isActive = currentNode?.id == node.id
        return Button {
            Haptics.tap()
            onSelect(node)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isActive ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isActive ? Theme.accentSoft : Theme.surfaceElevated))
            .overlay(Capsule().strokeBorder(isActive ? Theme.accent.opacity(0.4) : Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(QuietButtonStyle())
    }

    private func lockedChipView(icon: String, label: String) -> some View {
        Button(action: onLockedFolder) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.accentViolet)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accentViolet.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Theme.accentViolet.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(QuietButtonStyle())
    }
}

#Preview {
    QuickAccessChips(
        currentNode: FolderNode.directory(FileService.shared.rootURL, named: "On My iPhone"),
        onSelect: { _ in },
        onLockedFolder: {}
    )
    .background(Theme.background)
}