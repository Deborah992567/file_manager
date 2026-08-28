import SwiftUI

/// Batch-action bar that slides up while in multi-select mode.
/// Each tile is a spring-pressed icon button; every dispatch fires haptics.
struct SelectionActionBar: View {
    let count: Int
    let onMove: () -> Void
    let onCopy: () -> Void
    let onZip: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let onSelectAll: () -> Void
    let onClose: () -> Void

    private struct Action: Identifiable {
        let id: String
        let icon: String
        let label: String
        let tint: Color
        let destructive: Bool
    }

    private var actions: [Action] {
        [
            Action(id: "move", icon: "folder", label: "Move", tint: Theme.accent, destructive: false),
            Action(id: "copy", icon: "doc.on.doc", label: "Copy", tint: Theme.accentViolet, destructive: false),
            Action(id: "zip", icon: "archivebox", label: "Zip", tint: Theme.warning, destructive: false),
            Action(id: "share", icon: "square.and.arrow.up", label: "Share", tint: Theme.success, destructive: false),
            Action(id: "delete", icon: "trash", label: "Delete", tint: Theme.danger, destructive: true),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.textTertiary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.surfaceElevated))
                }
                .buttonStyle(QuietButtonStyle())

                Text("\(count) selected")
                    .font(Theme.Font.body(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 4)

                Spacer()

                Button(action: onSelectAll) {
                    Text("Select all")
                        .font(Theme.Font.body(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(actions) { action in
                        Button {
                            Haptics.mediumTap()
                            switch action.id {
                            case "move": onMove()
                            case "copy": onCopy()
                            case "zip": onZip()
                            case "share": onShare()
                            default: onDelete()
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(action.tint)
                                    .frame(width: 44, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(action.tint.opacity(0.13))
                                    )
                                Text(action.label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(PressEffectButtonStyle(pressedScale: 0.9))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: -6)
    }
}