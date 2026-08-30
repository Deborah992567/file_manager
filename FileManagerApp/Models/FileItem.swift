import Foundation
import SwiftUI

/// A file (or folder) surfaced by `FileService`, ready for the UI layer.
///
/// `id` is the absolute path — unique within the sandbox for the lifetime of
/// the data model. `FileItem` is a value copy of on-disk metadata; it is
/// regenerated after every mutation so SwiftUI diffing stays correct.
struct FileItem: Identifiable, Hashable, Sendable {
    let id: String          // url.path — unique within the sandbox
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let creationDate: Date
    let isHidden: Bool
    let fileExtension: String
    let kind: FileKind

    init(
        url: URL,
        isDirectory: Bool,
        size: Int64,
        modificationDate: Date,
        creationDate: Date,
        isHidden: Bool = false
    ) {
        self.url = url
        self.id = url.path
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.isHidden = isHidden
        self.fileExtension = url.pathExtension.lowercased()
        self.kind = FileKind.kind(for: url, isDirectory: isDirectory)
    }

    /// Display size, "(folder)" for directories which report 0 bytes.
    var displaySize: String {
        isDirectory ? "Folder" : ByteFormatter.format(size)
    }

    /// Uppercased extension for display; empty for folders.
    var displayExtension: String {
        isDirectory ? "" : fileExtension.uppercased()
    }
}

// MARK: - File kind

/// Semantic classification used to pick icons, colors and search filters.
enum FileKind: String, CaseIterable, Identifiable, Sendable {
    case folder, image, video, audio, document, archive, code, text, other

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .folder:   return "folder.fill"
        case .image:    return "photo.fill"
        case .video:    return "film.fill"
        case .audio:    return "music.note"
        case .document: return "doc.fill"
        case .archive:  return "archivebox.fill"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .text:     return "doc.plaintext.fill"
        case .other:    return "questionmark.square.fill"
        }
    }

    /// Diagnostic color on thumbnails (also used by the storage donut chart).
    var tint: Color {
        switch self {
        case .folder:   return Theme.accent
        case .image:    return Theme.success
        case .video:    return Color(hex: 0x8B5CF6)
        case .audio:    return Color(hex: 0xF472B6)
        case .document: return Theme.accent
        case .archive:  return Theme.warning
        case .code:     return Color(hex: 0x22D3EE)
        case .text:     return Color(hex: 0xA1A1A8)
        case .other:    return Color(hex: 0x6B6B72)
        }
    }

    var label: String { rawValue.capitalized }

    var category: FileCategory {
        switch self {
        case .folder:                        return .documents
        case .image, .video, .audio:         return .media
        case .archive:                       return .downloads
        case .document, .code, .text, .other: return .documents
        }
    }

    /// Extension map — extensible so new types drop in via one line.
    static func kind(for url: URL, isDirectory: Bool) -> FileKind {
        guard !isDirectory else { return .folder }
        let ext = url.pathExtension.lowercased()
        return kind(forExtension: ext)
    }

    static func kind(forExtension ext: String) -> FileKind {
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "bmp", "raw":
            return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "webm", "mpeg", "mpg", "3gp":
            return .video
        case "mp3", "m4a", "wav", "aac", "flac", "aiff", "caf", "opus":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key", "rtf", "odt":
            return .document
        case "zip", "rar", "tar", "gz", "7z", "bz2", "xz", "tgz", "dmg":
            return .archive
        case "swift", "m", "h", "mm", "c", "cpp", "py", "js", "ts", "json", "xml",
             "html", "css", "yml", "yaml", "sh", "rb", "go", "rs", "java", "kt", "sql":
            return .code
        case "txt", "md", "log", "csv", "icloud":
            return .text
        default:
            return .other
        }
    }
}

// MARK: - Storage category (donut chart segments)

enum FileCategory: String, CaseIterable, Sendable {
    case documents, media, downloads, other

    var label: String {
        switch self {
        case .documents: return "Documents"
        case .media:     return "Media"
        case .downloads: return "Downloads"
        case .other:     return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .media:     return "photo.on.rectangle.angled"
        case .downloads: return "arrow.down.circle.fill"
        case .other:     return "shippingbox.fill"
        }
    }

    var color: Color {
        switch self {
        case .documents: return Theme.accent
        case .media:     return Theme.success
        case .downloads: return Theme.warning
        case .other:     return Theme.accentViolet
        }
    }
}

// MARK: - Color tags

/// Color tagging model — stored as raw string so it serializes trivially
/// into `UserDefaults`. `none` means "untagged".
enum TagColor: String, CaseIterable, Identifiable, Sendable {
    case none, red, orange, yellow, green, blue, violet

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .none:   return Theme.accent
        case .red:    return Theme.danger
        case .orange: return Color(hex: 0xFB923C)
        case .yellow: return Theme.warning
        case .green:  return Theme.success
        case .blue:   return Color(hex: 0x60A5FA)
        case .violet: return Theme.accentViolet
        }
    }

    var label: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"; case .orange: return "Orange"
        case .yellow: return "Yellow"; case .green: return "Green"
        case .blue: return "Blue"; case .violet: return "Violet"
        }
    }
}