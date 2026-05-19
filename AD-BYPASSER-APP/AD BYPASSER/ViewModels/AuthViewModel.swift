import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var username: String = ""
    var password: String = ""
    var fullName: String = ""
    var email: String = ""

    var usernameError: String?
    var passwordError: String?
    var emailError: String?

    var isWorking: Bool = false

    private let store: AuthStore
    init(store: AuthStore) { self.store = store }

    func validateForLogin() -> Bool {
        usernameError = Validators.username(username)
        passwordError = password.isEmpty ? String(localized: "validation.password.required") : nil
        return usernameError == nil && passwordError == nil
    }

    func validateForRegister() -> Bool {
        usernameError = Validators.username(username)
        passwordError = Validators.password(password)
        emailError = Validators.email(email)
        return usernameError == nil && passwordError == nil && emailError == nil
    }

    func login() async {
        guard validateForLogin() else { return }
        isWorking = true
        await store.login(username: username, password: password)
        isWorking = false
    }

    func register() async -> Bool {
        guard validateForRegister() else { return false }
        isWorking = true
        let ok = await store.register(
            username: username,
            password: password,
            fullName: fullName.isEmpty ? nil : fullName,
            email: email.isEmpty ? nil : email
        )
        isWorking = false
        return ok
    }
}
