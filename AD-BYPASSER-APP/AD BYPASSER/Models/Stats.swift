import Foundation

struct TodayStats: Codable, Equatable {
    let queries: Int
    let blocked: Int
    let daily_limit: Int
    let block_ratio: Double
}

struct HistoryPoint: Codable, Identifiable, Equatable {
    let date: String
    let queries: Int
    let blocked: Int
    var id: String { date }

    var dateValue: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: date)
    }
}

struct HistoryResponse: Codable, Equatable {
    let period: String
    let days: Int
    let points: [HistoryPoint]
}

struct AdminOverview: Codable, Equatable {
    let users: UserCounts
    let adguard: AdGuardStats?

    struct UserCounts: Codable, Equatable {
        let total: Int
        let active: Int
        let pending: Int
        let suspended: Int
    }

    struct AdGuardStats: Codable, Equatable {
        let num_dns_queries: Int?
        let num_blocked_filtering: Int?
        let avg_processing_time: Double?
    }
}
