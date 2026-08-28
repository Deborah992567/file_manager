import Foundation
import LocalAuthentication
import Observation

/// Biometric gate for the app lock and the Locked Folder.
///
/// Wraps `LocalAuthentication`. All callers are async and awaited from the
/// view layer, which turns failures into a distinct lock-shake animation
/// rather than a silent no-op.
@MainActor
@Observable
final class SecurityService {

    static let shared = SecurityService()

    enum AuthError: LocalizedError {
        case unavailable
        case userCancel
        case fallback
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Face ID / Touch ID is not set up on this device."
            case .userCancel:  return "Authentication was cancelled."
            case .fallback:    return "Passcode required."
            case .failed(let d): return d
            }
        }
    }

    /// True when the device has a usable biometric policy (not merely present).
    var isBiometricAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Prompt the user for biometrics. `fallbackMessage` is what we tell them
    /// to expect inside the system sheet ("Unlock exposure", …).
    func authenticate(reason: String) async -> Result<Void, Error> {
        let context = LAContext()
        let biometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let policy: LAPolicy = biometrics ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: nil) else {
            return .failure(AuthError.unavailable)
        }

        do {
            try await context.evaluatePolicy(policy, localizedReason: reason)
            return .success(())
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return .failure(AuthError.userCancel)
            case .authenticationFailed:
                return .failure(AuthError.failed("Authentication failed — try again."))
            case .userFallback:
                return .failure(AuthError.fallback)
            default:
                return .failure(AuthError.failed(error.localizedDescription))
            }
        } catch {
            return .failure(AuthError.failed(error.localizedDescription))
        }
    }
}