import SwiftUI

/// Identifiable wrapper so the preview can be presented as a sheet item.
struct FilePreviewContext: Identifiable {
    let id = UUID()
    let item: FileItem
}

/// The file preview bottom sheet: blurred backdrop, interactive drag physics,
/// metadata header, quick actions, tag picker and native Quick Look.
struct FilePreviewSheet: View {
    let context: FilePreviewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: PreviewViewModel
    @State private var showQuickLook = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var showMovePicker = false

    init(context: FilePreviewContext) {
        self.context = context
        _vm = State(initialValue: PreviewViewModel(item: context.item))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.textTertiary.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    tagPicker
                    actionRow
                    if !vm.item.isDirectory {
                        openButton
                    }
                    infoRows
                }
                .padding(20)
            }

            Spacer(minLength: 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.fraction(0.42), .large])
        .presentationBackground(Theme.background)
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showRename) { renameSheet }
        .sheet(isPresented: $showMovePicker) {
            FolderPickerView(
                rootURL: FileService.shared.rootURL,
                excludedIDs: [vm.item.url.path]
            ) { destination in move(to: destination) }
        }
        .confirmationDialog("Delete “\(vm.item.name)”?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This moves the file to the trash. You can undo it.")
        }
        .fullScreenCover(isPresented: $showQuickLook) {
            QuickLookView(urls: [vm.item.url])
                .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            FileThumbnailView(item: vm.item, size: 64, tag: FileService.shared.tag(for: vm.item))

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.item.name)
                    .font(Theme.Font.display(20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(vm.item.kind.label, systemImage: vm.item.kind.symbolName)
                    if !vm.item.isDirectory {
                        Text("·")
                        Text(ByteFormatter.format(vm.storageSize))
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                Haptics.tap()
                dismissPreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.surfaceElevated))
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.top, 16)
    }

    private var tagPicker: some View {
        HStack {
            Text("Tag")
                .font(Theme.Font.body(13, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            HStack(spacing: 10) {
                ForEach(TagColor.allCases) { tag in
                    let current = FileService.shared.tag(for: vm.item)
                    Button {
                        Haptics.tick()
                        FileService.shared.setTag(tag, for: vm.item)
                        if tag == .none {
                            appState.showToast(.info("Removed tag", subtitle: vm.item.name))
                        } else {
                            appState.showToast(.success("Tagged", subtitle: "\(vm.item.name) · \(tag.label)"))
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(tag == .none ? Color.clear : tag.color)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(current == tag ? Theme.accent : Theme.surfaceStroke, lineWidth: current == tag ? 2 : 1))
                            if tag == .none {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            if current == tag {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(12)
        .contentCard()
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            previewAction("MOVE", icon: "folder", tint: Theme.accent) { showMovePicker = true }
            previewAction("RENAME", icon: "pencil", tint: Theme.accentViolet, disabled: false) {
                renameText = vm.item.nameWithoutExtension
                showRename = true
            }
            previewAction("SHARE", icon: "square.and.arrow.up", tint: Theme.success) { Share.files([vm.item]) }
            PreviewActionButton("INFO", icon: "info.circle", tint: nil) { presentInfo() }
            previewAction("DELETE", icon: "trash", tint: Theme.danger) {
                Haptics.warn()
                showDeleteConfirm = true
            }
        }
        .padding(.vertical, 4)
    }

    private func previewAction(_ label: String, icon: String, tint: Color, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        PreviewActionButton(label, icon: icon, tint: tint) { Haptics.tap(); action() }
    }

    private var openButton: some View {
        Button {
            Haptics.tap()
            showQuickLook = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                Text("Open with Quick Look")
            }
            .font(Theme.Font.body(16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(PressEffectButtonStyle())
        .padding(.top, 4)
    }

    private var infoRows: some View {
        Group {
            infoRow("Path", value: vm.item.url.deletingLastPathComponent().lastPathComponent)
            infoRow("Modified", value: DateFormatting.fileDate(vm.item.modificationDate))
            infoRow("Created", value: DateFormatting.fileDate(vm.item.creationDate))
            infoRow("Type", value: vm.item.isDirectory ? "Folder" : vm.item.displayExtension)
        }
        .padding(.top, 6)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.Font.body(13, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Text(value)
                .font(Theme.Font.body(13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename")
                .font(Theme.Font.display(20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            TextField("Name", text: $renameText)
                .font(Theme.Font.body(16, weight: .medium))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.surfaceStroke, lineWidth: 1))
                .presentationBackground(Theme.surface)
            Button {
                Haptics.rigidTap()
                rename()
            } label: {
                Text("Save")
                    .font(Theme.Font.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(PressEffectButtonStyle())
        }
        .padding(20)
        .presentationDetents([.height(210)])
        .presentationBackground(Theme.surface)
    }

    private func rename() {
        switch vm.rename(to: renameText) {
        case .success:
            appState.showToast(.success("Renamed", subtitle: "New name is \(vm.item.name)"))
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private func move(to destination: URL) {
        Haptics.tap()
        // Move through the shared service then refresh local item.
        do {
            try FileService.shared.move([vm.item], to: destination)
            appState.showToast(.success("Moved", subtitle: vm.item.name))
            dismissPreview()
        } catch {
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private func delete() {
        switch vm.delete() {
        case .success(let mapping):
            appState.showToast(.success("Deleted", subtitle: vm.item.name, actionTitle: "Undo") {
                try? FileService.shared.restoreDeletions(mapping)
                appState.showToast(.success("Restored", subtitle: vm.item.name))
            })
            dismissPreview()
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private func presentInfo() {
        Haptics.tick()
        appState.showToast(.info("\(vm.item.name)", subtitle: "\(ByteFormatter.format(vm.storageSize)) · \(DateFormatting.fileDate(vm.item.modificationDate))"))
    }

    private func dismissPreview() {
        dismiss()
    }
}

/// One tile in the preview action row.
struct PreviewActionButton: View {
    let label: String
    let icon: String
    let tint: Color?
    let action: () -> Void

    init(_ label: String, icon: String, tint: Color?, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint ?? Theme.textSecondary)
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceElevated))
        }
        .buttonStyle(PressEffectButtonStyle(pressedScale: 0.92))
    }
}

#Preview {
    FilePreviewSheet(context: FilePreviewContext(item: FileItem(
        url: URL(fileURLWithPath: "/tmp/Report.pdf"),
        isDirectory: false,
        size: 2048,
        modificationDate: .now,
        creationDate: .now
    )))
    .environment(AppState())
}