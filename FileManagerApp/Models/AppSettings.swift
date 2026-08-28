import Foundation
import Observation

/// User-persisted preferences with automatic `UserDefaults` persistence.
///
/// Single `shared` instance injected via `.environment()`. Every property
/// uses a `didSet` so a setting change writes through instantly — and
/// because it's `@Observable`, any view reading it re-renders on change.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Keys

    private enum Keys {
        static let onboardingDone = "settings.onboardingDone"
        static let biometric      = "settings.biometricLock"
        static let theme          = "settings.theme"
        static let accent         = "settings.accent"
        static let viewMode       = "settings.viewMode"
        static let sort           = "settings.sort"
        static let lockedFolder   = "settings.lockedFolderCreated"
    }

    private let defaults: UserDefaults

    // MARK: - State (all persisted)

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingDone) }
    }

    /// Master switch for Face ID / Touch ID app lock.
    var isBiometricEnabled: Bool {
        didSet { defaults.set(isBiometricEnabled, forKey: Keys.biometric) }
    }

    var themePreference: ThemePreference {
        didSet { defaults.set(themePreference.rawValue, forKey: Keys.theme) }
    }

    var accentChoice: AccentChoice {
        didSet { defaults.set(accentChoice.rawValue, forKey: Keys.accent) }
    }

    var defaultViewMode: ViewMode {
        didSet { defaults.set(defaultViewMode.rawValue, forKey: Keys.viewMode) }
    }

    var defaultSort: SortOption {
        didSet { defaults.set(defaultSort.rawValue, forKey: Keys.sort) }
    }

    var lockedFolderExists: Bool {
        didSet { defaults.set(lockedFolderExists, forKey: Keys.lockedFolder) }
    }

    /// The accent color currently in use anywhere in the UI.
    var effectiveAccent: Color { accentChoice.color }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingDone)
        self.isBiometricEnabled = defaults.bool(forKey: Keys.biometric)
        self.themePreference = ThemePreference(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .dark
        self.accentChoice = AccentChoice(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .blue
        self.defaultViewMode = ViewMode(rawValue: defaults.string(forKey: Keys.viewMode) ?? "") ?? .grid
        self.defaultSort = SortOption(rawValue: defaults.string(forKey: Keys.sort) ?? "") ?? .name
        self.lockedFolderExists = defaults.bool(forKey: Keys.lockedFolder)
    }
}