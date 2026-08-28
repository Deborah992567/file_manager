import Foundation
import Observation

/// Settings + storage-management screen state.
@MainActor
@Observable
final class SettingsViewModel {

    private let settings = AppSettings.shared
    private let storageService = StorageService.shared
    private let fileService = FileService.shared
    private let securityService = SecurityService.shared

    var snapshot: StorageService.Snapshot?
    var isClearingCache = false
    var clearedBytes: Int64 = 0

    /// Refresh the storage breakdown; called on appear and after any change.
    func loadUsage() {
        snapshot = storageService.snapshot(for: fileService.rootURL)
    }

    /// Frees trash/cache space, reporting how much it actually reclaimed.
    func clearCache() async {
        isClearingCache = true
        // Small delay so the animated progress has something to convey.
        try? await Task.sleep(nanoseconds: 380_000_000)
        clearedBytes = fileService.clearCaches()
        isClearingCache = false
        loadUsage()
    }

    var isBiometricAvailable: Bool { securityService.isBiometricAvailable }

    func toggleBiometric(_ enabled: Bool) {
        settings.isBiometricEnabled = enabled
        Haptics.rigidTap()
    }
}