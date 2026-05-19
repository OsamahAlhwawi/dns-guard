import Foundation

struct DNSStatusResponse: Codable, Equatable {
    let status: Status
    let is_active: Bool
    let is_suspended: Bool
    let expires_at: String?

    enum Status: String, Codable {
        case active
        case pending_activation
        case suspended
        case expired
        case unknown
    }
}

struct DNSConfigResponse: Codable, Equatable {
    let doh_url: String
    let status: DNSStatusResponse.Status
}
