import SwiftUI

/// Single row in list mode with color-coded swipe actions (delete / move /
/// rename / star) and an optional selection checkmark.
struct FileListRow: View {
    let item: FileItem
    let isSelected: Bool
    let tag: TagColor?
    let isSelecting: Bool
    let onTap: (FileItem) -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onMove: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button {
            onTap(item)
        } label: {
            HStack(spacing: 12) {
                if isSelecting {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Theme.accent : Color.clear)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(Theme.textTertiary.opacity(0.6), lineWidth: 1.4))
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                FileThumbnailView(item: item, size: 42, tag: tag)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text(item.isDirectory ? "Folder" : "\(item.fileExtension.uppercased()) · \(ByteFormatter.format(item.size))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                Text(DateFormatting.compact(item.modificationDate))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.accentSoft : Theme.surfaceElevated.opacity(0.55))
            )
        }
        .buttonStyle(FlatListButtonStyle())
        .contextMenu {
            ContextMenuPopup.menu(for: item, tag: tag)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in onLongPress() }
        )
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onToggleFavorite) {
                Label(tag == nil ? "Star" : "Unstar", systemImage: "star.fill")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(Theme.danger)

            Button(action: onMove) {
                Label("Move", systemImage: "folder")
            }
            .tint(Theme.accent)

            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            .tint(Theme.surfaceElevated)
        }
    }
}

private struct FlatListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(AppMotion.quick, value: configuration.isPressed)
    }
}

#Preview {
    FileListRow(
        item: FileItem(url: URL(fileURLWithPath: "/tmp/Report.pdf"), isDirectory: false, size: 2048, modificationDate: .now, creationDate: .now),
        isSelected: true,
        tag: .violet,
        isSelecting: true,
        onTap: { _ in },
        onLongPress: {},
        onDelete: {},
        onRename: {},
        onMove: {},
        onToggleFavorite: {}
    )
    .padding(16)
    .background(Theme.background)
}