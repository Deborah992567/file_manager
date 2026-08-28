import Foundation
import Observation

/// Per-file state for the preview bottom sheet: metadata, quick-actions
/// (rename / delete / move / info) and the mutation results surfaced as toasts.
///
/// Kept as small as possible — most heavy lifting belongs to `FileService`.
@MainActor
@Observable
final class PreviewViewModel {

    private let service: FileService
    private let storageService = StorageService.shared

    private(set) var item: FileItem
    var storageSize: Int64 = 0

    /// Set when the user is editing the name (rename sheet prefill offset).
    var renameDraft = ""

    init(item: FileItem, service: FileService = .shared) {
        self.item = item
        self.service = service
        renameDraft = item.nameWithoutExtension
        measure()
    }

    private func measure() {
        storageSize = storageService.size(of: item.url)
    }

    /// Replace the held item after a rename/move completes.
    func replace(with newItem: FileItem) {
        item = newItem
        renameDraft = newItem.nameWithoutExtension
        measure()
    }

    func rename(to newName: String) -> Result<FileItem, Error> {
        do {
            let renamed = try service.rename(item, to: newName)
            replace(with: renamed)
            return .success(renamed)
        } catch {
            return .failure(error)
        }
    }

    func delete() -> Result<[URL: URL], Error> {
        do {
            let mapping = try service.delete([item])
            return .success(mapping)
        } catch {
            return .failure(error)
        }
    }

    func toggleFavorite() {
        if service.isFavorite(item) {
            service.setTag(.none, for: item)
        } else {
            service.setTag(.blue, for: item)
        }
        Haptics.tick()
    }
}

// MARK: - File name helpers

extension FileItem {
    /// "report.pdf" → "report" (used to pre-fill rename sheets).
    var nameWithoutExtension: String {
        isDirectory ? name : (url.deletingPathExtension().lastPathComponent)
    }
}