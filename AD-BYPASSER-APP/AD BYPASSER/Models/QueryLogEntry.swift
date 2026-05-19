import Foundation

/// Mirror of AdGuard Home's /control/querylog entry. Only the fields we render.
struct QueryLogEntry: Codable, Identifiable, Equatable {
    let time: String
    let question: Question
    let reason: String?
    let elapsedMs: String?
    let upstream: String?
    let client: String?

    var id: String { time + (question.name) }
    var isBlocked: Bool { (reason ?? "").contains("Filtered") || (reason ?? "").contains("Blocked") }

    struct Question: Codable, Equatable {
        let name: String
        let type: String?
        let `class`: String?
    }

    enum CodingKeys: String, CodingKey {
        case time, question, reason
        case elapsedMs = "elapsedMs"
        case upstream, client
    }
}

struct QueryLogResponse: Codable, Equatable {
    let client_id: String?
    let log: QueryLogPayload?

    struct QueryLogPayload: Codable, Equatable {
        let data: [QueryLogEntry]?
        let oldest: String?
    }
}
