import Foundation

/// One crumb in the breadcrumb trail.
///
/// The file browser keeps a stack of these: `[Node(root) … Node(current)]`.
/// Directory nodes carry a real `URL`; virtual nodes (Recents / Favorites)
/// are resolved by `FileService`, which owns the underlying data.
struct FolderNode: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case directory   // real folder on disk
        case recents     // recently-touched files (virtual)
        case favorites   // starred items (virtual)
        case locked      // biometric-gated folder on disk
    }

    let id: String
    let name: String
    let url: URL?
    let kind: Kind

    var isVirtual: Bool { url == nil }

    // MARK: - Factory helpers

    static func directory(_ url: URL) -> FolderNode {
        FolderNode(id: url.path, name: url.lastPathComponent, url: url, kind: .directory)
    }

    static func directory(_ url: URL, named name: String) -> FolderNode {
        FolderNode(id: url.path, name: name, url: url, kind: .directory)
    }

    static let recents = FolderNode(id: "virtual:recents", name: "Recents", url: nil, kind: .recents)
    static let favorites = FolderNode(id: "virtual:favorites", name: "Favorites", url: nil, kind: .favorites)

    static func locked(_ url: URL) -> FolderNode {
        FolderNode(id: url.path, name: "Locked Folder", url: url, kind: .locked)
    }

    // MARK: - Identifiable / Hashable (id is authoritative)

    static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}