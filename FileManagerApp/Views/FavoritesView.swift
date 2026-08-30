import SwiftUI

/// Starred items tab: everything tagged in the app, filterable by kind,
/// with one-tap untagging and folder jumps back into the browser.
struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    @State private var vm: FavoritesViewModel
    @State private var previewContext: FilePreviewContext?

    init() {
        _vm = State(initialValue: FavoritesViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $previewContext) { context in
            FilePreviewSheet(context: context)
                .environment(appState)
        }
        .onAppear { vm.reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorites")
                    .font(Theme.Font.display(30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if !vm.items.isEmpty {
                    Button {
                        Haptics.warn()
                        vm.clearAllTags()
                        appState.showToast(.info("Cleared favorites", subtitle: "All stars and tags removed"))
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.surfaceElevated))
                    }
                    .buttonStyle(PressEffectButtonStyle())
                    .accessibilityLabel("Clear all favorites")
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(KindFilter.allCases) { kind in
                        let isSelected = vm.filter == kind
                        Button {
                            Haptics.tick()
                            withAnimation(AppMotion.quick) {
                                vm.filter = kind
                                vm.reload()
                            }
                        } label: {
                            Text(kind.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(isSelected ? Theme.accentSoft : Theme.surfaceElevated))
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }

            Text(vm.items.isEmpty ? "No favorites yet" : "\(vm.items.count) starred item\(vm.items.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 18)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var content: some View {
        if vm.items.isEmpty {
            EmptyStateView(
                icon: "star.slash",
                title: "Nothing starred yet",
                subtitle: "Long-press the star on any file or folder to keep it here.",
                actionTitle: nil,
                action: nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.items) { item in
                        row(item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
    }

    private func row(_ item: FileItem) -> some View {
        Button {
            Haptics.tap()
            if item.isDirectory {
                NotificationCenter.default.post(name: .openFolder, object: FolderNode.directory(item.url))
            } else {
                FileService.shared.markOpened(item)
                previewContext = FilePreviewContext(item: item)
            }
        } label: {
            HStack(spacing: 12) {
                FileThumbnailView(item: item, size: 46, tag: FileService.shared.tag(for: item))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(Theme.Font.body(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(item.isDirectory ? "Folder" : "\(item.displayExtension) · \(ByteFormatter.format(item.size))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()

                Button {
                    Haptics.tick()
                    vm.untag(item)
                    appState.showToast(.info("Removed from Favorites", subtitle: item.name))
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.warning)
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentCard()
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? "Opens this folder" : "Opens a preview of this file")
        .accessibilityAction(named: "Remove from Favorites") {
            Haptics.tick()
            vm.untag(item)
            appState.showToast(.info("Removed from Favorites", subtitle: item.name))
        }
    }
}

#Preview {
    FavoritesView()
        .environment(AppState())
}