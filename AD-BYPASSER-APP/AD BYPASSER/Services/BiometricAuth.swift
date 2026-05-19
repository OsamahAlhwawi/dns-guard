import Foundation
import LocalAuthentication

enum BiometricAuth {
    enum Result {
        case success
        case unavailable
        case failed(String)
    }

    static var isAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    static func authenticate(reason: String) async -> Result {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return ok ? .success : .failed("denied")
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
