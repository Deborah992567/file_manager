import Foundation
import Observation

/// State for the biometric-gated Locked Folder screen.
///
/// The folder itself lives on disk like any other, but every read goes
/// through an `unlock()` session; locking again clears the in-memory listing
/// so sensitive names never linger in SwiftUI.
@MainActor
@Observable
final class LockedFolderViewModel {

    private let service: FileService
    private let security: SecurityService

    private(set) var items: [FileItem] = []
    private(set) var isUnlocked = false
    private(set) var lastAuthError: String?

    init(service: FileService? = nil, security: SecurityService? = nil) {
        self.service = service ?? .shared
        self.security = security ?? .shared
    }

    var folderExists: Bool { service.hasLockedFolder }

    func createFolder() -> Result<Void, Error> {
        do {
            try service.createLockedFolder()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Biometric gate: only on success do we list the folder contents.
    func unlock() async {
        let result = await security.authenticate(reason: "Unlock your Locked Folder")
        switch result {
        case .success:
            isUnlocked = true
            lastAuthError = nil
            reload()
            Haptics.success()
        case .failure(let error):
            lastAuthError = error.localizedDescription
            Haptics.error()
        }
    }

    func lock() {
        isUnlocked = false
        items = []
        Haptics.tap()
    }

    func reload() {
        items = (try? service.items(in: service.lockedFolderURL)) ?? []
    }

    func delete(_ item: FileItem) -> Result<[URL: URL], Error> {
        do {
            let mapping = try service.delete([item])
            reload()
            return .success(mapping)
        } catch {
            return .failure(error)
        }
    }
}