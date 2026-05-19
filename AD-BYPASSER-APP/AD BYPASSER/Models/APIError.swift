import Foundation

enum APIError: Error, LocalizedError, Equatable {
    case transport(String)
    case decoding(String)
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case server(Int, String)
    case validation(String)
    case noNetwork

    var errorDescription: String? {
        switch self {
        case .transport: return String(localized: "error.transport")
        case .decoding: return String(localized: "error.decoding")
        case .unauthorized: return String(localized: "error.unauthorized")
        case .forbidden: return String(localized: "error.forbidden")
        case .notFound: return String(localized: "error.not_found")
        case .conflict(let m): return m
        case .server(_, let m): return m
        case .validation(let m): return m
        case .noNetwork: return String(localized: "error.no_network")
        }
    }
}

struct ServerErrorPayload: Codable {
    let error: String
}
