import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var todayStats: TodayStats?
    private(set) var status: DNSStatusResponse?
    private(set) var lastRefreshed: Date?
    var lastError: String?
    var isWorking: Bool = false

    private let api = APIClient.shared
    private var pollTask: Task<Void, Never>?

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(Constants.foregroundStatusPollSeconds))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        do {
            async let s = api.dnsStatus()
            async let t = api.todayStats()
            self.status = try await s
            self.todayStats = try await t
            self.lastRefreshed = .now
            self.lastError = nil
        } catch let APIError.forbidden {
            // pending/suspended — clear today stats but keep status fetch separately if it succeeded
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
