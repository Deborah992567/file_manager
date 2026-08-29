import SwiftUI

/// One grid tile in the browser. Passed raw values (no view-model) so it
/// stays a dumb, reusable component. The parent attaches `matchedGeometryEffect`
/// for hero expansion and the press/haptic feedback lives here.
struct FileGridCell: View {
    let item: FileItem
    let isSelected: Bool
    let tag: TagColor?
    let isSelecting: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack(alignment: .topLeading) {
                    FileThumbnailView(item: item, size: 62, tag: tag)

                    if isSelecting {
                        selectionMark
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(spacing: 3) {
                    Text(item.name)
                        .font(Theme.Font.body(13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 34, alignment: .top)

                    Text(item.isDirectory ? "Folder" : ByteFormatter.format(item.size))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Theme.accentSoft : Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressEffectButtonStyle())
        .contextMenu {
            ContextMenuPopup.menu(for: item, tag: tag)  // shared menu builder
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in onLongPress() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.isDirectory ? "folder" : ByteFormatter.format(item.size))")
        .accessibilityHint(item.isDirectory ? "Opens this folder" : "Opens a preview of this file")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectionMark: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.accent : Theme.surfaceElevated)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Theme.surfaceStroke, lineWidth: 1))

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(4)
        .allowsHitTesting(false)
    }
}

#Preview {
    FileGridCell(
        item: FileItem(url: URL(fileURLWithPath: "/tmp/Report.pdf"), isDirectory: false, size: 2048, modificationDate: .now, creationDate: .now),
        isSelected: false,
        tag: .blue,
        isSelecting: false,
        onTap: {},
        onLongPress: {}
    )
    .padding(20)
    .background(Theme.background)
}