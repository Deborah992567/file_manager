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

    init(service: FileService? = nil) {
        self.service = service ?? .shared
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

    var isEmpty: Bool { items.isEmpty }
}