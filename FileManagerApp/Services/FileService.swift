import Foundation
import Observation
import SwiftUI

/// Errors surfaced from `FileService` — mapped to user-facing toasts/alerts
/// by the UI layer so failures are never silent.
enum FileOperationError: LocalizedError {
    case permissionDenied
    case diskFull
    case invalidPath
    case nameExists(String)
    case itemMissing(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permission denied — the file sandbox blocked this operation."
        case .diskFull:         return "Not enough free space on this device."
        case .invalidPath:      return "That location is no longer available."
        case .nameExists(let n): return "A file named “\(n)” already exists here."
        case .itemMissing(let n): return "“\(n)” could not be found."
        case .unknown(let e):   return e.localizedDescription
        }
    }
}

/// Single on-disk file store backing the whole app (MVVM service layer).
///
/// Wraps `FileManager` on the app's sandboxed Documents directory and owns
/// the derived state that isn't pure filesystem: favorites + color tags,
/// recently-opened items and the biometric-gated Locked Folder.
@MainActor
@Observable
final class FileService {

    static let shared = FileService()

    /// Sandbox Documents directory — the browsable "On My iPhone" root.
    let rootURL: URL
    var lockedFolderURL: URL { rootURL.appendingPathComponent("Locked Folder") }

    private let fm: FileManager
    private let defaults: UserDefaults

    // MARK: - Persisted derived state

    /// Recently opened items (most recent first). Persisted as relative paths
    /// so values survive sandbox remapping between launches.
    private(set) var recents: [FileItem] = []

    private enum Keys {
        static let tags   = "file.tags"          // [relativePath : TagColor.rawValue]
        static let recents = "file.recents"      // [String] relative paths, newest first
        static let locked = "file.lockedCreated"
    }

    // MARK: - Init

    init(fm: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fm = fm
        self.defaults = defaults
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.rootURL = docs
        loadRecents()
        createMissingDefaultFolders()
    }

    private func createMissingDefaultFolders() {
        let defaults = ["Downloads"]
        for name in defaults {
            let url = rootURL.appendingPathComponent(name, isDirectory: true)
            if !fm.fileExists(atPath: url.path) { try? fm.createDirectory(at: url, withIntermediateDirectories: true) }
        }
    }

    // MARK: - Indexing

    static func item(at url: URL) -> FileItem? {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
        return FileItem(
            url: url,
            isDirectory: values.isDirectory ?? false,
            size: values.fileSize.map { Int64($0) } ?? 0,
            modificationDate: values.contentModificationDate ?? Date(),
            creationDate: values.creationDate ?? Date(),
            isHidden: values.isHidden ?? false
        )
    }

    /// Contents of a directory, sorted by name (case-insensitive), directories
    /// interleaved alphabetically as Finder does.
    func items(in url: URL) throws -> [FileItem] {
        let contents = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )
        return contents.compactMap { FileService.item(at: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Path helpers

    /// Relative path under the sandbox root, the stable key for tags/recents.
    func relativePath(for url: URL) -> String {
        let root = rootURL.path
        var p = url.path
        if p.hasPrefix(root) { p = String(p.dropFirst(root.count)) }
        while p.hasPrefix("/") { p.removeFirst() }
        return p
    }

    private func resolve(relativePath path: String) -> URL {
        let url = rootURL.appendingPathComponent(path)
        return url
    }

    // MARK: - Folder / file operations

    @discardableResult
    func createFolder(named name: String, in parent: URL) throws -> FileItem {
        let target = uniqueSiblingURL(for: parent.appendingPathComponent(name, isDirectory: true))
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        guard let item = FileService.item(at: target) else { throw FileOperationError.invalidPath }
        return item
    }

    @discardableResult
    func rename(_ item: FileItem, to newName: String) throws -> FileItem {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FileOperationError.itemMissing(newName) }
        var destination = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        if !item.isDirectory { destination = destination.appendingPathExtension(item.url.pathExtension) }
        guard !fm.fileExists(atPath: destination.path) else { throw FileOperationError.nameExists(trimmed) }
        try fm.moveItem(at: item.url, to: destination)
        guard let moved = FileService.item(at: destination) else { throw FileOperationError.invalidPath }
        if let tag = tag(for: item), tag != .none {
            setTag(tag, for: moved)   // carry the tag through a rename
        }
        return moved
    }

    /// Moves items into a hidden trash folder inside the sandbox so "undo"
    /// can restore them; the trash is what "Clear cache" empties.
    func delete(_ items: [FileItem]) throws -> [URL: URL] {
        var moved: [URL: URL] = [:]
        let trash = rootURL.appendingPathComponent(".novaTrash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        for item in items {
            if item.isDirectory {
                // Recursively clear any stored tag children.
                removeTags(under: item.url)
            }
            let destination = uniqueSiblingURL(for: trash.appendingPathComponent(item.name))
            try fm.moveItem(at: item.url, to: destination)
            moved[item.url] = destination
        }
        return moved
    }

    /// Undo for a previous `delete` call (toast action).
    func restoreDeletions(_ mapping: [URL: URL]) throws {
        for (original, trashed) in mapping {
            if fm.fileExists(atPath: trashed.path) {
                try fm.moveItem(at: trashed, to: uniqueSiblingURL(for: original))
            }
        }
    }

    func move(_ items: [FileItem], to destination: URL) throws {
        let destDir = destination.hasDirectoryPath ? destination : destination.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        for item in items {
            let target = uniqueSiblingURL(for: destDir.appendingPathComponent(item.name))
            if target == item.url { continue }
            try fm.moveItem(at: item.url, to: target)
        }
    }

    func copy(_ items: [FileItem], to destination: URL) throws {
        let destDir = destination.hasDirectoryPath ? destination : destination.deletingLastPathComponent()
        try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        for item in items {
            let target = uniqueSiblingURL(for: destDir.appendingPathComponent(item.name))
            try fm.copyItem(at: item.url, to: target)
        }
    }

    func duplicate(_ item: FileItem) throws -> FileItem {
        let parent = item.url.deletingLastPathComponent()
        let base = item.url.deletingPathExtension().lastPathComponent
        let ext = item.url.pathExtension.isEmpty ? "" : ".\(item.url.pathExtension)"
        let target = uniqueSiblingURL(for: parent.appendingPathComponent(base + " copy" + ext))
        try fm.copyItem(at: item.url, to: target)
        guard let copy = FileService.item(at: target) else { throw FileOperationError.invalidPath }
        return copy
    }

    /// Picks the first free sibling name ("name", "name 2", "name 3", …).
    private func uniqueSiblingURL(for url: URL) -> URL {
        guard fm.fileExists(atPath: url.path) else { return url }
        let parent = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidate: URL
            if ext.isEmpty {
                candidate = parent.appendingPathComponent("\(base) \(index)")
            } else {
                candidate = parent.appendingPathComponent("\(base) \(index).\(ext)")
            }
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    // MARK: - Favorites & tags

    private var tagStore: [String: String] {
        get { defaults.dictionary(forKey: Keys.tags) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Keys.tags) }
    }

    func tag(for item: FileItem) -> TagColor? {
        let key = relativePath(for: item.url)
        guard let raw = tagStore[key], let tag = TagColor(rawValue: raw), tag != .none else { return nil }
        return tag
    }

    func setTag(_ tag: TagColor, for item: FileItem) {
        var store = tagStore
        store[relativePath(for: item.url)] = tag == .none ? nil : tag.rawValue
        tagStore = store
    }

    func toastTagChange(for item: FileItem, to tag: TagColor) {
        setTag(tag, for: item)
    }

    func isFavorite(_ item: FileItem) -> Bool {
        tag(for: item) != nil
    }

    func favoriteItems() -> [FileItem] {
        tagStore.keys
            .sorted()
            .compactMap { FileService.item(at: resolve(relativePath: $0)) }
    }

    /// Removes every star/tag (Settings → Favorites → "Clear all").
    func clearAllTags() {
        tagStore = [:]
    }

    private func removeTags(under url: URL) {
        var store = tagStore
        let root = url.path
        for key in store.keys {
            if resolve(relativePath: key).path.hasPrefix(root) { store[key] = nil }
        }
        tagStore = store
    }

    // MARK: - Recents

    func markOpened(_ item: FileItem) {
        var paths = (defaults.array(forKey: Keys.recents) as? [String]) ?? []
        let key = relativePath(for: item.url)
        paths.removeAll { $0 == key }
        paths.insert(key, at: 0)
        defaults.set(Array(paths.prefix(20)), forKey: Keys.recents)
        loadRecents()
    }

    func recentItems() -> [FileItem] {
        recents
    }

    private func loadRecents() {
        let paths = (defaults.array(forKey: Keys.recents) as? [String]) ?? []
        recents = paths.compactMap { FileService.item(at: resolve(relativePath: $0)) }
    }

    // MARK: - Locked folder

    var hasLockedFolder: Bool {
        let created = defaults.bool(forKey: Keys.locked)
        return created || fm.fileExists(atPath: lockedFolderURL.path)
    }

    func createLockedFolder() throws {
        try fm.createDirectory(at: lockedFolderURL, withIntermediateDirectories: true)
        defaults.set(true, forKey: Keys.locked)
    }

    // MARK: - Downloads convenience

    var downloadsURL: URL { rootURL.appendingPathComponent("Downloads", isDirectory: true) }

    // MARK: - Cache / free-space housekeeping

    /// Frees temporary + trash space (Settings → Storage → "Free up space").
    func clearCaches() -> Int64 {
        var freed: Int64 = 0
        let candidates = [rootURL.appendingPathComponent(".novaTrash"), fm.temporaryDirectory]
        for base in candidates {
            let contents = (try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for url in contents {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                if (try? fm.removeItem(at: url)) != nil {
                    freed += Int64(size)
                }
            }
        }
        return freed
    }
}