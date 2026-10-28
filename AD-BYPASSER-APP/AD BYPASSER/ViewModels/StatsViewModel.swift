import Foundation
import Observation

@MainActor
@Observable
final class StatsViewModel {
    enum Period: String, CaseIterable, Identifiable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        var id: String { rawValue }
        var titleKey: String {
            switch self {
            case .day: return "stats.period.day"
            case .week: return "stats.period.week"
            case .month: return "stats.period.month"
            }
        }
    }

    var period: Period = .week { didSet { Task { await reload() } } }
    private(set) var points: [HistoryPoint] = []
    private(set) var today: TodayStats?
    var isWorking: Bool = false
    var lastError: String?

    private let api = APIClient.shared

    func reload() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let h = api.history(period: period.rawValue)
            async let t = api.todayStats()
            self.points = try await h.points
            self.today = try await t
            self.lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
