import Foundation
import Observation

/// State for the Favorites tab — the starred subset of the sandbox plus
/// quick access to tag-color rows. Reads live from `FileService` so unstarring
/// here is reflected instantly in the browser's grid cells.
@MainActor
@Observable
final class FavoritesViewModel {

    private let service: FileService

    private(set) var items: [FileItem] = []
    var filter: KindFilter = .all
    var isSelecting = false
    var selected: Set<String> = []

    init(service: FileService = .shared) {
        self.service = service
    }

    func reload() {
        var all = service.favoriteItems()
        if filter != .all {
            all = all.filter { filter.matches($0.kind) }
        }
        items = all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func clearAllTags() {
        service.clearAllTags()
        reload()
    }

    func untag(_ item: FileItem) {
        service.setTag(.none, for: item)
        reload()
        Haptics.tick()
    }

    func retag(_ item: FileItem, to color: TagColor) {
        service.setTag(color, for: item)
        reload()
        Haptics.tap()
    }

    func toggleSelection(_ item: FileItem) {
        if selected.contains(item.id) { selected.remove(item.id) }
        else { selected.insert(item.id) }
    }

    func enterSelection() {
        isSelecting = true
        selected = []
        Haptics.mediumTap()
    }

    func exitSelection() {
        isSelecting = false
        selected = []
    }

    var isEmpty: Bool { items.isEmpty }
}