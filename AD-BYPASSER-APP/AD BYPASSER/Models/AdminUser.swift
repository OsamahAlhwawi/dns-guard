import Foundation

/// Same shape as `User` for admin list/detail; using the same model keeps the API surface uniform.
typealias AdminUser = User

struct AdminUsersResponse: Codable, Equatable {
    let users: [AdminUser]
}

struct AdminUserStatsResponse: Codable, Equatable {
    let today: TodayUsage
    let history: [HistoryPoint]
    let user: User

    struct TodayUsage: Codable, Equatable {
        let queries: Int
        let blocked: Int
    }
}

struct AdminUserUpdate: Codable {
    var is_active: Bool?
    var is_suspended: Bool?
    var role: User.Role?
    var daily_limit: Int?
    var expires_at: String?
}

struct AuthTokens: Codable, Equatable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let user: User?
}

struct RegisterResponse: Codable, Equatable {
    let status: String
    let user: PendingUser

    struct PendingUser: Codable, Equatable {
        let id: Int
        let username: String
        let is_active: Bool
        let role: User.Role
    }
}
