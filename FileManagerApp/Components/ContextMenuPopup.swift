import SwiftUI

/// Custom blur-backdrop context menu, shared between native context menus
/// and the in-app overlay popup.
///
/// Two layers:
///  - `menu(for:tag:)` — a plain `Button` action list reused inside
///    `.contextMenu` (native) so grid/list items get identical actions.
///  - `ContextMenuPopup` — the full overlay: dimmed + blurred backdrop with a
///    spring scale-in card. Used by the browser as an alternative to the
///    system menu so the app owns the entire feel.
enum ContextMenuPopup {

    // MARK: - Shared actions (native context menu)

    static func menu(
        for item: FileItem,
        tag: TagColor?,
        onToggleFavorite: @escaping () -> Void = {},
        onDuplicate: @escaping () -> Void = {},
        onRename: @escaping () -> Void = {},
        onMove: @escaping () -> Void = {},
        onZip: @escaping () -> Void = {},
        onShare: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) -> some View {
        Group {
            Button(action: onToggleFavorite) { Label(tag == nil ? "Add to Favorites" : "Remove from Favorites", systemImage: "star") }

            if !item.isDirectory {
                Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
            }
            Button(action: onRename) { Label("Rename", systemImage: "pencil") }
            Button(action: onMove) { Label("Move", systemImage: "folder") }
            Button(action: onZip) { Label(item.isDirectory ? "Compress" : "Zip", systemImage: "archivebox") }
            Button(action: onShare) { Label("Share", systemImage: "square.and.arrow.up") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        }
    }
}

/// Overlay card: spring scale-in on top of a frosted, dimmed backdrop.
/// Wraps an action list provided by the caller.
struct ContextMenuOverlay<Actions: View>: View {
    let title: String
    @ViewBuilder var actions: () -> Actions
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .onTapGesture {
                    Haptics.tick()
                    withAnimation(AppMotion.spring) { onDismiss() }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Font.display(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, 8)

                actions()
                    .font(Theme.Font.body(15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    Haptics.tick()
                    withAnimation(AppMotion.spring) { onDismiss() }
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceElevated))
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.top, 6)
            }
            .padding(20)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 30, y: 14)
            .scaleEffect(appeared ? 1 : 0.86, anchor: .center)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(AppMotion.spring) { appeared = true }
        }
    }
}