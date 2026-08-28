import SwiftUI

/// Application entry point.
/// The whole app is driven by a single `AppState` observable that owns
/// launch phases (splash → onboarding → main), the lock screen, theme and
/// global toast routing.
@main
struct NovaFilesApp: App {
    @State private var appState: AppState
    @State private var settings = AppSettings.shared

    init() {
        // Root-level singletons we build once and share everywhere.
        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(settings)
        }
    }
}