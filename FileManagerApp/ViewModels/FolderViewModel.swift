import Foundation
import Observation

/// Browser state for a single folder node (real directory or virtual
/// Recents/Favorites/Locked). Each push into a sub-folder gets its own
/// instance, so breadcrumbs and hero-expansions are trivially independent.
@MainActor
@Observable
final class FolderViewModel {

    let service: FileService
    let node: FolderNode

    private(set) var items: [FileItem] = []
    private(set) var isRefreshing = false

    var sortOption: SortOption
    var sortDirection: SortDirection
    var viewMode: ViewMode

    // MARK: - Selection mode

    var isSelecting = false
    var selected: Set<String> = []

    var selectedItems: [FileItem] {
        items.filter { selected.contains($0.id) }
    }

    private let storageService = StorageService.shared

    // MARK: - Init

    init(node: FolderNode, service: FileService? = nil, settings: AppSettings? = nil) {
        self.node = node
        self.service = service ?? .shared
        self.sortOption = (settings ?? .shared).defaultSort
        self.sortDirection = .ascending
        self.viewMode = (settings ?? .shared).defaultViewMode
        reload()
    }

    // MARK: - Loading

    func reload() {
        switch node.kind {
        case .directory, .locked:
            guard let url = node.url else { items = []; return }
            items = (try? service.items(in: url)) ?? []
        case .recents:
            items = service.recentItems()
        case .favorites:
            items = service.favoriteItems()
        }
        sortItems()
    }

    /// Pull-to-refresh: re-scans the tree. Kept async so the custom refresh
    /// indicator has something real to await.
    func refresh() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 240_000_000)  // let the spinner read
        reload()
        isRefreshing = false
    }

    // MARK: - Sorting

    func sortItems() {
        // Folders always first (Finder convention), respecting the active sort
        // within each group.
        let dirs = items.filter(\.isDirectory)
        let files = items.filter { !$0.isDirectory }
        let comparator = makeComparator()
        items = dirs.sorted(by: comparator) + files.sorted(by: comparator)
    }

    private func makeComparator() -> (FileItem, FileItem) -> Bool {
        let asc = sortDirection == .ascending
        var desc: (FileItem, FileItem) -> Bool
        switch sortOption {
        case .name: desc = { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: desc = { $0.modificationDate < $1.modificationDate }
        case .size: desc = { self.size(of: $0) < self.size(of: $1) }
        case .type: desc = { $0.fileExtension < $1.fileExtension }
        }
        return asc ? desc : { !desc($0, $1) }
    }

    private func size(of item: FileItem) -> Int64 {
        item.isDirectory ? storageService.size(of: item.url) : item.size
    }

    // MARK: - Selection

    func toggleSelection(_ item: FileItem) {
        if selected.contains(item.id) {
            selected.remove(item.id)
        } else {
            selected.insert(item.id)
        }
    }

    func enterSelection(_ item: FileItem) {
        isSelecting = true
        selected = [item.id]
        Haptics.mediumTap()
    }

    func exitSelection() {
        isSelecting = false
        selected = []
    }

    // MARK: - Mutations (delegated to services; errors surface via returned Result)

    func createFolder(named name: String) -> Result<FileItem, FileOperationError> {
        guard let url = directoryURL else { return .failure(.invalidPath) }
        do {
            let item = try service.createFolder(named: name, in: url)
            reload()
            return .success(item)
        } catch let e as FileOperationError { return .failure(e) }
        catch { return .failure(.unknown(error)) }
    }

    func rename(_ item: FileItem, to newName: String) -> Result<FileItem, Error> {
        do {
            let renamed = try service.rename(item, to: newName)
            reload()
            return .success(renamed)
        } catch { return .failure(error) }
    }

    func moveSelection(to destination: URL) -> Result<Void, Error> {
        do {
            try service.move(selectedItems, to: destination)
            exitSelection()
            reload()
            return .success(())
        } catch { return .failure(error) }
    }

    func copySelection(to destination: URL) -> Result<Void, Error> {
        do {
            try service.copy(selectedItems, to: destination)
            exitSelection()
            reload()
            return .success(())
        } catch { return .failure(error) }
    }

    /// Moves selection to the in-sandbox trash; returns the mapping so the
    /// UI can offer an Undo action on the toast.
    func deleteSelection() -> Result<[URL: URL], Error> {
        do {
            let mapping = try service.delete(selectedItems)
            exitSelection()
            reload()
            return .success(mapping)
        } catch { return .failure(error) }
    }

    func delete(_ item: FileItem) -> Result<[URL: URL], Error> {
        do {
            let mapping = try service.delete([item])
            reload()
            return .success(mapping)
        } catch { return .failure(error) }
    }

    func duplicate(_ item: FileItem) -> Result<FileItem, Error> {
        do {
            let copy = try service.duplicate(item)
            reload()
            return .success(copy)
        } catch { return .failure(error) }
    }

    func toggleFavorite(_ item: FileItem) {
        if service.isFavorite(item) {
            service.setTag(.none, for: item)
        } else {
            service.setTag(.blue, for: item)
        }
        reload()
        Haptics.tick()
    }

    // MARK: - Helpers

    var directoryURL: URL? {
        switch node.kind {
        case .directory, .locked: return node.url
        // Virtual roots map to the top sandbox folder for new-item creation.
        case .recents, .favorites: return service.rootURL
        }
    }

    var isEmpty: Bool { items.isEmpty }
}