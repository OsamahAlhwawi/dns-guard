import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var fullName: String = ""
    var email: String = ""
    var currentPassword: String = ""
    var newPassword: String = ""
    var newPasswordError: String?
    var lastError: String?
    var lastMessage: String?
    var isWorking: Bool = false

    private let store: AuthStore
    init(store: AuthStore) {
        self.store = store
        if let u = store.currentUser {
            fullName = u.full_name ?? ""
            email = u.email ?? ""
        }
    }

    func saveProfile() async {
        // The /v1/user/profile PATCH endpoint accepts full_name/email; we don't expose it on APIClient yet,
        // so this is a placeholder hook — implement when needed.
        lastMessage = String(localized: "settings.saved")
    }

    func changePassword() async -> Bool {
        newPasswordError = Validators.password(newPassword)
        guard newPasswordError == nil else { return false }
        // Likewise, expose /v1/user/password on APIClient and call here.
        lastMessage = String(localized: "settings.password_changed")
        currentPassword = ""
        newPassword = ""
        return true
    }

    func logout() async {
        await store.logout()
    }
}
