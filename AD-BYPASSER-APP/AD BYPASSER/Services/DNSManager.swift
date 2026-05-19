import Foundation
import NetworkExtension
import Darwin
import Observation

/// Wraps NEDNSSettingsManager — install/remove a DoH profile that points at the
/// user's per-token DoH endpoint. Same code path on iOS and Mac Catalyst.
@MainActor
@Observable
final class DNSManager {
    static let shared = DNSManager()

    private(set) var isEnabled: Bool = false
    private(set) var isInstalled: Bool = false
    private(set) var currentServerURL: URL?
    private(set) var lastResolvedIPs: [String] = []
    var lastError: String?

    private let manager = NEDNSSettingsManager.shared()
    private let log = AppLog.shared

    private init() {}

    func refresh() async {
        do {
            try await manager.loadFromPreferences()
            isInstalled = manager.dnsSettings != nil
            isEnabled = manager.isEnabled
            currentServerURL = (manager.dnsSettings as? NEDNSOverHTTPSSettings)?.serverURL
            log.info("DNS", "refresh installed=\(isInstalled) enabled=\(isEnabled) url=\(currentServerURL?.absoluteString ?? "nil")")
        } catch {
            log.error("DNS", "refresh failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            isInstalled = false
            isEnabled = false
            currentServerURL = nil
        }
    }

    /// Install the DoH profile. First call on a device triggers the system approval prompt.
    func enable(dohURL: URL) async throws {
        let host = dohURL.host ?? ""
        // Resolve via the *current* system DNS BEFORE the DoH profile becomes active.
        // The resolved IPs are baked into the profile as `servers:` so iOS connects
        // directly to the VPS instead of trying to bootstrap-resolve the hostname
        // (which would fail in a chicken-and-egg way once our profile is the only DNS).
        let ips = await Self.resolve(host: host)
        lastResolvedIPs = ips
        log.info("DNS", "enable() URL=\(dohURL.absoluteString) host=\(host) resolved=\(ips.joined(separator: ", "))")

        try await manager.loadFromPreferences()

        let settings = NEDNSOverHTTPSSettings(servers: ips)
        settings.serverURL = dohURL
        manager.dnsSettings = settings
        manager.localizedDescription = Constants.dnsProfileLabel

        do {
            try await manager.saveToPreferences()
            log.info("DNS", "saveToPreferences ok")
        } catch let error as NSError where Self.isConfigurationUnchanged(error) {
            log.info("DNS", "saveToPreferences returned configurationUnchanged (treated as success)")
        } catch {
            log.error("DNS", "saveToPreferences failed: \(error.localizedDescription)")
            throw error
        }

        try await manager.loadFromPreferences()
        isInstalled = manager.dnsSettings != nil
        isEnabled = manager.isEnabled
        currentServerURL = (manager.dnsSettings as? NEDNSOverHTTPSSettings)?.serverURL
        lastError = nil
        log.info("DNS", "post-save installed=\(isInstalled) enabled=\(isEnabled) url=\(currentServerURL?.absoluteString ?? "nil")")
    }

    /// Wipe any saved profile and reinstall fresh.
    func reinstall(dohURL: URL) async throws {
        log.info("DNS", "reinstall() — removing then re-adding")
        try? await manager.loadFromPreferences()
        if manager.dnsSettings != nil {
            try? await manager.removeFromPreferences()
            try? await manager.loadFromPreferences()
            log.info("DNS", "removed previous profile")
        }
        try await enable(dohURL: dohURL)
    }

    func disable() async throws {
        log.info("DNS", "disable() — removing profile")
        try await manager.loadFromPreferences()
        if manager.dnsSettings != nil {
            try await manager.removeFromPreferences()
        }
        try? await manager.loadFromPreferences()
        isInstalled = false
        isEnabled = false
        currentServerURL = nil
        lastResolvedIPs = []
        lastError = nil
        log.info("DNS", "profile removed")
    }

    // MARK: - Helpers

    private static func isConfigurationUnchanged(_ error: NSError) -> Bool {
        error.code == 9 && (error.domain == "NEConfigurationErrorDomain"
                            || error.domain == "NEDNSSettingsManagerErrorDomain")
    }

    /// Synchronous getaddrinfo wrapped in a Task — runs on a background queue so
    /// MainActor isn't blocked. Returns IPv4 first, then IPv6.
    private static func resolve(host: String) async -> [String] {
        guard !host.isEmpty else { return [] }
        return await Task.detached(priority: .userInitiated) {
            var hints = addrinfo(
                ai_flags: 0,
                ai_family: AF_UNSPEC,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )
            var result: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, nil, &hints, &result) == 0, let head = result else {
                return []
            }
            defer { freeaddrinfo(head) }

            var v4: [String] = []
            var v6: [String] = []
            var ptr: UnsafeMutablePointer<addrinfo>? = head
            while let info = ptr?.pointee {
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let ok = getnameinfo(info.ai_addr, info.ai_addrlen,
                                     &buf, socklen_t(buf.count),
                                     nil, 0, NI_NUMERICHOST) == 0
                if ok {
                    let s = String(cString: buf)
                    if info.ai_family == AF_INET { v4.append(s) }
                    else if info.ai_family == AF_INET6 { v6.append(s) }
                }
                ptr = info.ai_next
            }
            return v4 + v6
        }.value
    }
}
