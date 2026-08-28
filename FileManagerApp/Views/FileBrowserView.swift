import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Core browsing screen (grid + list, breadcrumbs, quick access, sorting,
/// selection, drag & drop, hero folder expansion, import and the storage bar).
///
/// Recursion: rendering this view *inside* the hero overlay gives nested
/// folders a full browser with its own breadcrumb; the top-level instance
/// (`includeHomeChrome`) adds chips, storage bar and search entry.
struct FileBrowserView: View {
    let root: FolderNode
    var includeHomeChrome: Bool = true
    var onOpenSearch: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    @State private var viewModel: FolderViewModel
    @State private var stack: [FolderNode]
    @Namespace private var heroNS

    // Overlays / sheets
    @State private var heroItem: FileItem?
    @State private var previewContext: FilePreviewContext?
    @State private var showSort = false
    @State private var showNewMenu = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var createFolderPrompt = false
    @State private var folderName = ""
    @State private var renameItem: FileItem?
    @State private var renameText = ""
    @State private var showFolderPickerForBatch = false
    @State private var batchOperation: BatchOperation = .move
    @State private var confirmDeleteItem: FileItem?
    @State private var confirmBatchDelete = false
    @State private var showStorage = false
    @State private var importedImages: [UIImage] = []

    private enum BatchOperation {
        case move, copy
    }

    private var currentNode: FolderNode { stack.last ?? root }
    private var isRoot: Bool { stack.count == 1 && currentNode.kind == .directory && currentNode.url == FileService.shared.rootURL }
    private let fileService = FileService.shared
    private let storageService = StorageService.shared

    init(root: FolderNode, includeHomeChrome: Bool = true, onOpenSearch: (() -> Void)? = nil) {
        self.root = root
        self.includeHomeChrome = includeHomeChrome
        self.onOpenSearch = onOpenSearch
        _viewModel = State(initialValue: FolderViewModel(node: root))
        _stack = State(initialValue: [root])
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if includeHomeChrome || stack.count > 1 { gridHeader }
                content
            }

            // Hero folder expansion overlay (top-level folders only).
            if let hero = heroItem {
                FileBrowserView(
                    root: FolderNode.directory(hero.url),
                    includeHomeChrome: false
                )
                .matchedGeometryEffect(id: hero.id, in: heroNS)
                .environment(appState)
                .transition(.opacity)
                .zIndex(2)
                .overlay(alignment: .topLeading) {
                    backChip { closeHero() }
                }
            }

            if viewModel.isSelecting {
                selectionBar
                    .zIndex(3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showNewMenu {
                ContextMenuOverlay(title: "New & Import") {
                    overlayRow("New Folder", icon: "folder.badge.plus") { createFolderPrompt = true; showNewMenu = false }
                    overlayRow("Import Files", icon: "square.and.arrow.down") { showDocumentPicker = true; showNewMenu = false }
                    overlayRow("Import Photos", icon: "photo.on.rectangle.angled") { showPhotoPicker = true; showNewMenu = false }
                    overlayRow("Select All", icon: "checkmark.circle") { viewModel.selected = Set(viewModel.items.map(\.id)) }
                } onDismiss: { showNewMenu = false }
                .zIndex(10)
            }
        }
        .animation(AppMotion.spring, value: viewModel.isSelecting)
        .animation(AppMotion.spring, value: showNewMenu)
        .animation(AppMotion.hero, value: heroItem?.id)
        .sheet(isPresented: $showSort) {
            SortSheet(
                sortOption: Bindable(viewModel).sortOption,
                sortDirection: Bindable(viewModel).sortDirection,
                viewMode: Bindable(viewModel).viewMode
            )
        }
        .sheet(item: $previewContext) { context in
            FilePreviewSheet(context: context)
                .environment(appState)
        }
        .sheet(isPresented: $showFolderPickerForBatch) {
            FolderPickerView(
                rootURL: FileService.shared.rootURL,
                excludedIDs: Set(viewModel.selectedItems.map(\.url.path))
            ) { destination in runBatchOperation(to: destination) }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { urls in importDocuments(urls) }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { images in importedImages = images }
                .onAppear { }
        }
        .fullScreenCover(isPresented: $showStorage) {
            StorageView()
                .environment(appState)
        }
        .alert("New Folder", isPresented: $createFolderPrompt) {
            TextField("Folder name", text: $folderName)
            Button("Create") { createFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(confirmDeleteMessage, isPresented: confirmDeleteBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: viewModel.selected) { _, newSelection in
            // keep the confirmDelete dialog from leaking into selection state
        }
        .onChange(of: importedImages) { _, images in
            guard !images.isEmpty else { return }
            importPhotos(images)
            importedImages = []
        }
    }

    // MARK: - Header chrome

    private var gridHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if !includeHomeChrome {
                    backChip {
                        closeHero()
                    }
                }

                Text(currentNode.name)
                    .font(Theme.Font.display(26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                searchButton
                sortButton
                newButton
                viewToggle
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            if includeHomeChrome {
                QuickAccessChips(
                    currentNode: currentNode,
                    onSelect: jumpTo(node:),
                    onLockedFolder: presentLockedFolder
                )
            } else {
                BreadcrumbBar(crumbs: stack, onSelect: jumpToIndex)
                    .padding(.horizontal, 16)
            }

            storageBar
        }
.background(
            Rectangle().fill(Theme.background).shadow(color: .black.opacity(0.4), radius: 12, y: 6).mask(Rectangle().padding(.bottom, -12))
        )
    }

    private var searchButton: some View {
        HeaderIconButton(icon: "magnifyingglass", label: "Search") {
            onOpenSearch?()
        }
    }

    private var sortButton: some View {
        HeaderIconButton(icon: "arrow.up.arrow.down", label: "Sort") {
            showSort = true
        }
    }

    private var newButton: some View {
        HeaderIconButton(icon: "plus", label: "New", haptic: { Haptics.mediumTap() }) {
            showNewMenu = true
        }
    }

    private var viewToggle: some View {
        HeaderIconButton(
            icon: viewModel.viewMode == .grid ? "square.grid.2x2" : "list.bullet",
            label: "Toggle view",
            haptic: { Haptics.tick() }
        ) {
            withAnimation(AppMotion.spring) {
                viewModel.viewMode = viewModel.viewMode == .grid ? .list : .grid
            }
        }
    }

    private func backChip(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Circle().fill(Theme.surfaceElevated))
        }
        .buttonStyle(PressEffectButtonStyle())
    }

    @ViewBuilder private var storageBar: some View {
        if includeHomeChrome,
           let usage = storageService.deviceUsage {
            StorageBarView(
                fraction: Double(usage.used) / Double(max(1, usage.capacity)),
                freeLabel: "\(ByteFormatter.format(usage.free)) free",
                usedLabel: "\(ByteFormatter.format(usage.used)) used of \(ByteFormatter.format(usage.capacity))",
                onTap: {
                    Haptics.softTap()
                    showStorage = true
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if viewModel.isEmpty {
                EmptyStateView(
                    icon: currentNode.kind == .favorites ? "star.slash" : "tray",
                    title: currentNode.isVirtual ? "Nothing here yet" : "Empty folder",
                    subtitle: includeHomeChrome
                        ? "Add files, or long-press the + button to create a folder here."
                        : "",
                    actionTitle: includeHomeChrome ? "Add files" : nil,
                    action: includeHomeChrome ? { showNewMenu = true } : nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PullToRefresh(onRefresh: refresh) {
                    LazyVStack(spacing: 1) {
                        if viewModel.viewMode == .grid {
                            gridSection
                        } else {
                            listSection
                        }
                    }
                    .padding(.horizontal, viewModel.viewMode == .grid ? 12 : 8)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
        }
        .id(currentNode.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var gridSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            ForEach(viewModel.items) { item in
                gridCell(item)
            }
        }
    }

    private var listSection: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.items) { item in
                listRow(item)
            }
        }
    }

    // MARK: - Cells

    private func gridCell(_ item: FileItem) -> some View {
        Group {
            if heroItem?.id == item.id {
                Color.clear.frame(height: 148)
            } else {
                FileGridCell(
                    item: item,
                    isSelected: viewModel.selected.contains(item.id),
                    tag: fileService.tag(for: item),
                    isSelecting: viewModel.isSelecting,
                    onTap: { onTap(item) },
                    onLongPress: { onLongPress(item) }
                )
                .matchedGeometryEffect(id: item.id, in: heroNS)
                .onDrag {
                    dragProvider(for: item)
                }
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                    dropIntoFolder(providers: providers, item: item)
                }
            }
        }
    }

    private func listRow(_ item: FileItem) -> some View {
        FileListRow(
            item: item,
            isSelected: viewModel.selected.contains(item.id),
            tag: fileService.tag(for: item),
            isSelecting: viewModel.isSelecting,
            onTap: { _ in onTap(item) },
            onLongPress: { onLongPress(item) },
            onDelete: {
                Haptics.warn()
                confirmDeleteItem = item
            },
            onRename: {
                Haptics.tick()
                renameItem = item
                renameText = item.nameWithoutExtension
            },
            onMove: {
                moveSingle(item)
            },
            onToggleFavorite: {
                viewModel.toggleFavorite(item)
                appState.showToast(.success(viewModel.isSelecting ? "" : (fileService.isFavorite(item) ? "Added to Favorites" : "Removed from Favorites"),
                                           subtitle: item.name))
            }
        )
        .onDrag {
            dragProvider(for: item)
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            dropIntoFolder(providers: providers, item: item)
        }
    }

    // MARK: - Selection / interactions

    private func onTap(_ item: FileItem) {
        if viewModel.isSelecting {
            Haptics.tick()
            withAnimation(AppMotion.quick) { viewModel.toggleSelection(item) }
            return
        }
        if item.isDirectory {
            Haptics.mediumTap()
            if includeHomeChrome && stack.count == 1 {
                withAnimation(AppMotion.hero) { heroItem = item }
            } else {
                push(node: FolderNode.directory(item.url))
            }
        } else {
            Haptics.tap()
            fileService.markOpened(item)
            previewContext = FilePreviewContext(item: item)
        }
    }

    private func onLongPress(_ item: FileItem) {
        Haptics.mediumTap()
        withAnimation(AppMotion.spring) { viewModel.enterSelection(item) }
    }

    private var selectionBar: some View {
        SelectionActionBar(
            count: viewModel.selected.count,
            onMove: { batchOperation = .move; showFolderPickerForBatch = true },
            onCopy: { batchOperation = .copy; showFolderPickerForBatch = true },
            onZip: zipSelection,
            onShare: { Share.files(viewModel.selectedItems) },
            onDelete: {
                Haptics.warn()
                confirmBatchDelete = true
            },
            onSelectAll: {
                withAnimation(AppMotion.quick) { viewModel.selected = Set(viewModel.items.map(\.id)) }
            },
            onClose: {
                withAnimation(AppMotion.spring) { viewModel.exitSelection() }
            }
        )
    }

    // MARK: - Navigation

    private func push(node: FolderNode) {
        withAnimation(AppMotion.contentSwap) {
            stack.append(node)
            viewModel = FolderViewModel(node: node)
        }
    }

    private func jumpToIndex(_ index: Int) {
        guard index < stack.count else { return }
        let newStack = Array(stack.prefix(index + 1))
        withAnimation(AppMotion.contentSwap) {
            stack = newStack
            viewModel = FolderViewModel(node: newStack.last!)
        }
    }

    private func jumpTo(node: FolderNode) {
        guard currentNode.id != node.id else { return }
        withAnimation(AppMotion.contentSwap) {
            stack = [node]
            viewModel = FolderViewModel(node: node)
        }
    }

    private func closeHero() {
        withAnimation(AppMotion.hero) { heroItem = nil }
    }

    private func presentLockedFolder() {
        // Delegate upwards to RootView: the locked folder lives outside the
        // browser stack so it can own its biometric state.
        NotificationCenter.default.post(name: .openLockedFolder, object: nil)
    }

    // MARK: - Mutations

    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespaces)
        folderName = ""
        guard !name.isEmpty else { return }
        switch viewModel.createFolder(named: name) {
        case .success(let item):
            appState.showToast(.success("Folder created", subtitle: item.name))
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private var confirmDeleteMessage: String {
        if let item = confirmDeleteItem { return "Delete “\(item.name)”?" }
        if confirmBatchDelete { return "Delete \(viewModel.selected.count) items?" }
        return "Delete?"
    }

    private var confirmDeleteBinding: Binding<Bool> {
        Binding(
            get: { confirmDeleteItem != nil || confirmBatchDelete },
            set: { present in
                if !present {
                    confirmDeleteItem = nil
                    confirmBatchDelete = false
                }
            }
        )
    }

    private func performDelete() {
        let result: Result<[URL: URL], Error>
        if let item = confirmDeleteItem {
            result = viewModel.delete(item)
        } else {
            result = viewModel.deleteSelection()
        }
        confirmDeleteItem = nil
        confirmBatchDelete = false

        switch result {
        case .success(let mapping):
            let names = mapping.count == 1 ? mapping.first?.key.lastPathComponent : "\(mapping.count) items"
            appState.showToast(.success("Deleted", subtitle: mapping.count == 1 ? names : "", actionTitle: "Undo") {
                try? fileService.restoreDeletions(mapping)
                viewModel.reload()
                appState.showToast(.success("Restored", subtitle: mapping.count == 1 ? names : ""))
            })
        case .failure(let error):
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private func moveSingle(_ item: FileItem) {
        showFolderPickerForBatch = true
        viewModel.selected = [item.id]
        batchOperation = .move
    }

    private func runBatchOperation(to destination: URL) {
        switch batchOperation {
        case .move:
            switch viewModel.moveSelection(to: destination) {
            case .success:
                appState.showToast(.success("Moved", subtitle: "\(viewModel.selectedItems.count) files left behind"))
                withAnimation(AppMotion.spring) { viewModel.exitSelection() }
            case .failure(let error):
                Haptics.error()
                appState.showToast(.error(error.localizedDescription))
            }
        case .copy:
            switch viewModel.copySelection(to: destination) {
            case .success:
                appState.showToast(.success("Copied", subtitle: "Files copied into \(destination.lastPathComponent)"))
                withAnimation(AppMotion.spring) { viewModel.exitSelection() }
            case .failure(let error):
                Haptics.error()
                appState.showToast(.error(error.localizedDescription))
            }
        }
    }

    private func zipSelection() {
        let items = viewModel.selectedItems
        guard !items.isEmpty, let dir = viewModel.directoryURL else { return }
        let archiveName = FileService.shared.uniqueNameForArchive(base: items.count == 1 ? items[0].nameWithoutExtension : "Archive", in: dir)
        let archiveURL = dir.appendingPathComponent(archiveName)

        do {
            try ZipService.compress(items: items.map(\.url), to: archiveURL)
            viewModel.reload()
            Haptics.success()
            appState.showToast(.success("Compressed", subtitle: archiveName))
        } catch {
            Haptics.error()
            appState.showToast(.error(error.localizedDescription))
        }
    }

    private func importDocuments(_ urls: [URL]) {
        guard let dir = viewModel.directoryURL else { return }
        var imported = 0
        for url in urls {
            let target = FileService.shared.uniqueURL(in: dir, name: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: target)
                imported += 1
            } catch {
                // silent per-file failure so a single bad file doesn't block all
            }
        }
        viewModel.reload()
        if imported > 0 {
            Haptics.success()
            appState.showToast(.success("Imported", subtitle: imported == 1 ? urls.first!.lastPathComponent : "\(imported) files"))
        }
    }

    private func importPhotos(_ images: [UIImage]) {
        guard let dir = viewModel.directoryURL else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        var count = 0
        for (index, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
            let base = "IMG_" + formatter.string(from: Date()) + (images.count > 1 ? "_\(index + 1)" : "")
            let target = FileService.shared.uniqueURL(in: dir, name: base + ".jpg")
            try? data.write(to: target)
            count += 1
        }
        viewModel.reload()
        if count > 0 {
            Haptics.success()
            appState.showToast(.success("Photos imported", subtitle: count == 1 ? "1 image" : "\(count) images"))
        }
    }

    // MARK: - Drag & drop

    private func dragProvider(for item: FileItem) -> NSItemProvider {
        let provider = NSItemProvider()
        if !item.isDirectory {
            provider.registerFileRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
                completion(item.url, true, nil)
                return nil
            }
        }
        return provider
    }

    private func dropIntoFolder(providers: [NSItemProvider], item: FileItem) -> Bool {
        guard item.isDirectory else { return false }
        Haptics.softTap()
        for provider in providers {
            _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { itemData, _ in
                guard let data = itemData as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let dropped = FileService.item(at: url) else { return }
                Task { @MainActor in
                    do {
                        try self.fileService.move([dropped], to: item.url)
                        self.viewModel.reload()
                    } catch {
                        self.appState.showToast(.error(error.localizedDescription))
                    }
                }
            }
        }
        return true
    }

    private func refresh() async {
        await viewModel.refresh()
    }
}

// MARK: - Overlay row helper

extension FileBrowserView {
    private func overlayRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(QuietButtonStyle())
    }
}

extension Notification.Name {
    static let openLockedFolder = Notification.Name("openLockedFolder")
}