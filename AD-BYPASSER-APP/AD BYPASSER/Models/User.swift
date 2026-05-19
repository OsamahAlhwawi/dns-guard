import Foundation

struct User: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let username: String
    let email: String?
    let full_name: String?
    let role: Role
    let is_active: Bool
    let is_suspended: Bool
    let plan: String
    let daily_limit: Int
    let client_id: String
    let token: String
    let created_at: String
    let last_login: String?
    let expires_at: String?

    enum Role: String, Codable {
        case user
        case admin
    }

    var isAdmin: Bool { role == .admin }
    var dohURL: URL? {
        URL(string: "\(Constants.dnsBaseURL.absoluteString)/dns-query/\(token)")
    }
}
