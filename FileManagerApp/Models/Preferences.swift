import Foundation
import SwiftUI

/// Grid vs list presentation in the file browser.
enum ViewMode: String, CaseIterable, Identifiable, Sendable {
    case grid, list

    var id: String { rawValue }

    var label: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }

    var symbolName: String {
        switch self {
        case .grid: return "square.grid.2x2.fill"
        case .list: return "list.bullet"
        }
    }
}

/// Sort dimensions available in the browser's sort sheet.
enum SortOption: String, CaseIterable, Identifiable, Sendable {
    case name, date, size, type

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .date: return "Date Modified"
        case .size: return "Size"
        case .type: return "Type"
        }
    }

    var symbolName: String {
        switch self {
        case .name: return "textformat"
        case .date: return "calendar"
        case .size: return "arrow.up.arrow.down.square"
        case .type: return "square.stack.3d.up"
        }
    }
}

enum SortDirection: String, CaseIterable, Identifiable, Sendable {
    case ascending = "asc"
    case descending = "desc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending:  return "Ascending"
        case .descending: return "Descending"
        }
    }

    var symbolName: String {
        switch self {
        case .ascending:  return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

/// File-kind filter used by Search + Browse.
enum KindFilter: String, CaseIterable, Identifiable, Sendable {
    case all, folders, images, videos, audio, documents, archives

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Everything"
        case .folders: return "Folders"
        case .images: return "Images"
        case .videos: return "Video"
        case .audio: return "Audio"
        case .documents: return "Documents"
        case .archives: return "Archives"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "circle.grid.2x2"
        case .folders: return "folder.fill"
        case .images: return "photo.fill"
        case .videos: return "film.fill"
        case .audio: return "music.note"
        case .documents: return "doc.fill"
        case .archives: return "archivebox.fill"
        }
    }

    /// Does the filter pass for a given item kind?
    func matches(_ kind: FileKind) -> Bool {
        switch self {
        case .all: return true
        case .folders: return kind == .folder
        case .images: return kind == .image
        case .videos: return kind == .video
        case .audio: return kind == .audio
        case .documents: return kind == .document || kind == .text || kind == .code
        case .archives: return kind == .archive
        }
    }
}

/// Theme mode for the whole app.
enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// The single accent color choice — everything accent-derived reads this.
enum AccentChoice: String, CaseIterable, Identifiable, Sendable {
    case blue, violet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue: return "Electric Blue"
        case .violet: return "Violet"
        }
    }

    /// NOTE: swap-through uses this; `Theme.accent` is the default when no
    /// preference has been persisted yet.
    var color: Color {
        switch self {
        case .blue: return Color(hex: 0x4D8DFF)
        case .violet: return Color(hex: 0x8B5CF6)
        }
    }
}