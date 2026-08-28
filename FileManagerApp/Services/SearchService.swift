import Foundation
import Observation

/// Recursive, breadth-layered search over the whole sandbox.
///
/// Kept separate from `FileService` so the browser never carries search state.
/// Results come back pre-grouped the way the Search screen wants them
/// (by `FileKind`, or optionally flat).
@MainActor
@Observable
final class SearchService {

    static let shared = SearchService()

    struct ResultGroup: Identifiable {
        let kind: FileKind
        var items: [FileItem]
        var id: FileKind { kind }
    }

    private let fm = FileManager.default

    /// Search all files whose name contains `query` (case-insensitive).
    ///
    /// - Parameters:
    ///   - root: sandbox directory to search
    ///   - query: substring to match against filenames; empty matches nothing
    ///   - filter: optional kind filter, applied after the name match
    ///   - maxDepth: hard cap so deep trees can't hang the UI (recursion guard)
    func search(
        in root: URL,
        query: String,
        filter: KindFilter = .all,
        maxDepth: Int = 6
    ) async -> [ResultGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let permittedKinds = FileKind.allCases.filter { filter.matches($0) }

        // The heavy tree walk runs off the main actor; only names are matched
        // here. `FileItem` construction (MainActor) happens after we return.
        let matches = await Task.detached(priority: .userInitiated) { [fm] in
            var found: [(url: URL, isDirectory: Bool)] = []
            var stack: [(url: URL, depth: Int)] = [(root, 0)]

            while let next = stack.popLast() {
                guard next.depth <= maxDepth else { continue }
                guard let contents = try? fm.contentsOfDirectory(
                    at: next.url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for url in contents {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        stack.append((url, next.depth + 1))
                    }
                    guard url.lastPathComponent.localizedCaseInsensitiveContains(trimmed) else { continue }
                    found.append((url, isDir))
                }
            }
            return found
        }.value

        let items: [FileItem] = matches.compactMap { url, isDir in
            guard let item = FileService.item(at: url) else { return nil }
            let kind = isDir ? FileKind.folder : item.kind
            guard permittedKinds.contains(kind) else { return nil }
            return item
        }

        return Self.grouping(items, by: permittedKinds)
    }

    /// Paper-thin grouping helper so results can be sorted by importance or
    /// type without reshuffling matched content.
    static func grouping(_ items: [FileItem], by kinds: [FileKind] = FileKind.allCases) -> [ResultGroup] {
        let sorted = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return kinds
            .map { kind in (kind, sorted.filter { $0.kind == kind }) }
            .filter { !$0.1.isEmpty }
            .map { ResultGroup(kind: $0.0, items: $0.1) }
    }
}