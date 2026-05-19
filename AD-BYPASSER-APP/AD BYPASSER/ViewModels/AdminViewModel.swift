import Foundation
import Observation

@MainActor
@Observable
final class AdminViewModel {
    private(set) var pending: [User] = []
    private(set) var allUsers: [User] = []
    private(set) var overview: AdminOverview?
    var lastError: String?
    var isWorking: Bool = false

    private let api = APIClient.shared

    func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let p = api.adminListPending()
            async let a = api.adminListUsers()
            async let o = api.adminOverview()
            self.pending = try await p
            self.allUsers = try await a
            self.overview = try await o
            self.lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func activate(_ user: User) async {
        await update(user.id, patch: AdminUserUpdate(is_active: true))
    }

    func suspend(_ user: User) async {
        await update(user.id, patch: AdminUserUpdate(is_suspended: true))
    }

    func unsuspend(_ user: User) async {
        await update(user.id, patch: AdminUserUpdate(is_suspended: false))
    }

    func setRole(_ user: User, role: User.Role) async {
        await update(user.id, patch: AdminUserUpdate(role: role))
    }

    func setDailyLimit(_ user: User, limit: Int) async {
        await update(user.id, patch: AdminUserUpdate(daily_limit: limit))
    }

    func delete(_ user: User) async {
        do {
            try await api.adminDeleteUser(id: user.id)
            await reload()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func update(_ id: Int, patch: AdminUserUpdate) async {
        do {
            _ = try await api.adminUpdateUser(id: id, patch: patch)
            await reload()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class AdminUserDetailViewModel {
    let user: User
    private(set) var stats: AdminUserStatsResponse?
    private(set) var logEntries: [QueryLogEntry] = []
    var lastError: String?
    var isWorking: Bool = false

    private let api = APIClient.shared

    init(user: User) { self.user = user }

    func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let s = api.adminUserStats(id: user.id)
            async let l = api.adminUserLogs(id: user.id, limit: 100)
            self.stats = try await s
            self.logEntries = (try await l).log?.data ?? []
            self.lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
