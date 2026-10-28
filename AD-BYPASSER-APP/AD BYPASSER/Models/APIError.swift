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
        case .transport: return NSLocalizedString("error.transport", comment: "")
        case .decoding: return NSLocalizedString("error.decoding", comment: "")
        case .unauthorized: return NSLocalizedString("error.unauthorized", comment: "")
        case .forbidden: return NSLocalizedString("error.forbidden", comment: "")
        case .notFound: return NSLocalizedString("error.not_found", comment: "")
        case .conflict(let m): return m
        case .server(_, let m): return m
        case .validation(let m): return m
        case .noNetwork: return NSLocalizedString("error.no_network", comment: "")
        }
    }
}

struct ServerErrorPayload: Codable {
    let error: String
}
