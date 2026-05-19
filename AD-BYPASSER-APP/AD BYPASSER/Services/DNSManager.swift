import Foundation
import NetworkExtension
import Observation

/// Wraps NEDNSSettingsManager — install/remove a DoH profile that points at the
/// user's per-token DoH endpoint. Same code path on iOS and Mac Catalyst.
@MainActor
@Observable
final class DNSManager {
    static let shared = DNSManager()

    private(set) var isEnabled: Bool = false
    private(set) var isInstalled: Bool = false
    var lastError: String?

    private let manager = NEDNSSettingsManager.shared()

    private init() {}

    func refresh() async {
        do {
            try await manager.loadFromPreferences()
            isInstalled = manager.dnsSettings != nil
            isEnabled = manager.isEnabled
        } catch {
            lastError = error.localizedDescription
            isInstalled = false
            isEnabled = false
        }
    }

    /// Install the DoH profile. First call on a device triggers the system approval prompt.
    func enable(dohURL: URL) async throws {
        try await manager.loadFromPreferences()
        let settings = NEDNSOverHTTPSSettings(servers: Constants.dohBootstrapServers)
        settings.serverURL = dohURL
        manager.dnsSettings = settings
        manager.localizedDescription = Constants.dnsProfileLabel
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        isInstalled = manager.dnsSettings != nil
        isEnabled = manager.isEnabled
        lastError = nil
    }

    func disable() async throws {
        try await manager.loadFromPreferences()
        if manager.dnsSettings != nil {
            try await manager.removeFromPreferences()
        }
        try? await manager.loadFromPreferences()
        isInstalled = false
        isEnabled = false
        lastError = nil
    }
}
