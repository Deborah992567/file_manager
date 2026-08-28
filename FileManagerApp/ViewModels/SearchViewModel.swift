import Foundation
import Observation

/// Everything the Search screen needs: live query → grouped results, an
/// optional kind filter and a persisted "recent searches" pill row.
///
/// Debouncing happens here (not in the view) so typing never hammers the
/// filesystem; each keystroke cancels the previous in-flight search task.
@MainActor
@Observable
final class SearchViewModel {

    private let service: SearchService
    private let fileService: FileService
    private let defaults: UserDefaults

    private(set) var groups: [SearchService.ResultGroup] = []
    private(set) var isSearching = false
    var query = ""
    var filter: KindFilter = .all
    var recentSearches: [String] = []

    private var pendingTask: Task<Void, Never>?

    private enum Keys {
        static let recent = "search.recentQueries"
    }

    init(service: SearchService = .shared, fileService: FileService = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.fileService = fileService
        self.defaults = defaults
        self.recentSearches = defaults.array(forKey: Keys.recent) as? [String] ?? []
    }

    // MARK: - Live search

    /// Called from the text field's `.onChange(of:)` — debounced so this stays
    /// cheap while typing a multi-character term.
    func queryChanged() {
        pendingTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            groups = []
            isSearching = false
            return
        }
        pendingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)  // 220 ms debounce
            guard let self, !Task.isCancelled else { return }
            self.isSearching = true
            let results = await self.service.search(in: self.fileService.rootURL, query: self.query, filter: self.filter)
            guard !Task.isCancelled else { return }
            self.groups = results
            self.isSearching = false
        }
    }

    func applyFilter(_ kind: KindFilter) {
        guard kind != filter else { return }
        filter = kind
        queryChanged()
    }

    // MARK: - Recent searches

    func commitQuery() {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        var recents = recentSearches.filter { $0 != term }
        recents.insert(term, at: 0)
        recentSearches = Array(recents.prefix(10))
        defaults.set(recentSearches, forKey: Keys.recent)
    }

    func useRecent(_ term: String) {
        query = term
        queryChanged()
    }

    func clearRecents() {
        recentSearches = []
        defaults.set([String](), forKey: Keys.recent)
    }

    var resultCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }
}