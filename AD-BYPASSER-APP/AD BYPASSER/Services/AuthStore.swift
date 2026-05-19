import Foundation
import Observation

/// App-wide source of truth for auth state. Restored on launch from Keychain.
@MainActor
@Observable
final class AuthStore {
    enum State: Equatable {
        case unauthenticated
        case authenticating
        case authenticated(User)
        case pendingActivation(User)
    }

    var state: State = .unauthenticated
    var lastError: String?

    private let api = APIClient.shared

    init() {
        Task { await restore() }
    }

    func restore() async {
        guard await api.hasSession else {
            state = .unauthenticated
            return
        }
        do {
            let user = try await api.me()
            apply(user: user)
        } catch {
            await api.clearTokens()
            state = .unauthenticated
        }
    }

    func login(username: String, password: String) async {
        state = .authenticating
        lastError = nil
        do {
            let tokens = try await api.login(username: username, password: password)
            let user: User
            if let u = tokens.user { user = u } else { user = try await api.me() }
            apply(user: user)
        } catch let APIError.unauthorized {
            lastError = String(localized: "error.invalid_credentials")
            state = .unauthenticated
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .unauthenticated
        }
    }

    func register(username: String, password: String, fullName: String?, email: String?) async -> Bool {
        lastError = nil
        do {
            _ = try await api.register(username: username, password: password, fullName: fullName, email: email)
            // Immediately log in so the app can show the pending screen.
            await login(username: username, password: password)
            return true
        } catch let APIError.conflict(m) {
            lastError = m.isEmpty ? String(localized: "error.username_taken") : m
            return false
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func logout() async {
        try? await api.logout()
        await api.clearTokens()
        state = .unauthenticated
    }

    func refreshUser() async {
        do {
            let user = try await api.me()
            apply(user: user)
        } catch {
            // Stay on current state; the API client handles 401 → refresh internally.
        }
    }

    private func apply(user: User) {
        if user.is_suspended {
            state = .pendingActivation(user)  // treated like pending — user can't act
        } else if !user.is_active {
            state = .pendingActivation(user)
        } else {
            state = .authenticated(user)
        }
    }

    var currentUser: User? {
        switch state {
        case .authenticated(let u), .pendingActivation(let u): return u
        case .unauthenticated, .authenticating: return nil
        }
    }
}

