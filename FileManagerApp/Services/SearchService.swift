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

        let matches = await Task.detached(priority: .userInitiated) { [fm] in
            var found: [FileItem] = []
            var stack: [(url: URL, depth: Int)] = [(root, 0)]

            while let next = stack.popLast() {
                guard next.depth <= maxDepth else { continue }
                guard let contents = try? fm.contentsOfDirectory(
                    at: next.url,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for url in contents {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        stack.append((url, next.depth + 1))
                        // Folders still match a name search below.
                    }
                    let item = FileService.item(at: url)
                    guard let item else { continue }
                    guard item.name.localizedCaseInsensitiveContains(trimmed) else { continue }
                    if isDir, permittedKinds.contains(.folder) { found.append(item) }
                    if !isDir, permittedKinds.contains(item.kind) { found.append(item) }
                }
            }
            return found
        }.value

        return ResultGroup.grouping(matches, by: permittedKinds)
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