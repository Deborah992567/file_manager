import Foundation

/// Deterministic, cached formatting helpers (avoid re-creating formatters
/// on every cell — those are notoriously expensive).
enum ByteFormatter {
    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

enum DateFormatting {
    private static let fileDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let compact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func fileDate(_ date: Date) -> String {
        fileDate.string(from: date)
    }

    static func compact(_ date: Date) -> String {
        compact.string(from: date)
    }
}