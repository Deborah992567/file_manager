import Foundation
import Observation
import SwiftUI

/// Application-level state machine plus the global toast router.
///
/// `NovaFilesApp` owns a single instance and injects it into the environment;
/// screens drive launch phases (splash → onboarding → main), the biometric
/// lock overlay and every toast through here. Keeping this as one observable
/// avoids threading individual callbacks through unrelated view models.
@MainActor
@Observable
final class AppState {
    enum Phase {
        case splash
        case onboarding
        case main
    }

    static let shared = AppState()

    /// Which top-level scene is on screen right now.
    var phase: Phase = .splash

    /// True while the biometric lock screen is presented.
    var isLocked = false

    /// Monotonic counter that re-fires the toast presentation animation even
    /// when a new message replaces an identical one (same title/text).
    private(set) var toastToken = 0
    var toast: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    private let settings = AppSettings.shared

    // MARK: - Lifecycle

    /// Splash finished animating; route first-time users to onboarding.
    func launchCompleted() {
        phase = settings.hasCompletedOnboarding ? .main : .onboarding
    }

    /// Onboarding "Get Started" tapped; flip the first-launch flag and go.
    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        withAnimation(AppMotion.spring) { phase = .main }
    }

    // MARK: - Biometric app lock

    /// Called from `RootView.onAppear` each cold start.
    func engageBiometricLockIfNeeded() {
        guard settings.hasCompletedOnboarding, settings.isBiometricEnabled else { return }
        isLocked = true
    }

    func unlock() {
        withAnimation(AppMotion.spring) { isLocked = false }
    }

    // MARK: - Global toast

    /// Shows a transient toast; auto-dismisses after `autoDismiss` seconds.
    /// Consistent `.spring` settle, matching the rest of the app.
    func showToast(_ message: ToastMessage, autoDismiss: TimeInterval = 3.2) {
        toastToken += 1
        toast = message
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(autoDismiss * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismissToast()
        }
    }

    func dismissToast() {
        withAnimation(AppMotion.spring) { toast = nil }
    }
}