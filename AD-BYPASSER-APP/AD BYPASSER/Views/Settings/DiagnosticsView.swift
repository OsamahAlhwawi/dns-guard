import SwiftUI

struct DiagnosticsView: View {
    @Environment(AuthStore.self) private var auth
    private let dns = DNSManager.shared
    @State private var log = AppLog.shared
    @State private var healthCheckResult: String?
    @State private var dohCheckResult: String?
    @State private var working = false

    private var expectedDohURL: URL? { auth.currentUser?.dohURL }

    var body: some View {
        List {
            Section("diag.profile") {
                LabeledContent("diag.installed") { Text(dns.isInstalled ? "✅" : "❌") }
                LabeledContent("diag.enabled") { Text(dns.isEnabled ? "✅" : "❌") }
                LabeledContent("diag.expected_url") {
                    Text(expectedDohURL?.absoluteString ?? "-")
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
                LabeledContent("diag.installed_url") {
                    Text(dns.currentServerURL?.absoluteString ?? "-")
                        .font(.caption.monospaced())
                        .foregroundStyle(urlMismatch ? .red : .primary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
                if urlMismatch {
                    Text("diag.url_mismatch")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if !dns.lastResolvedIPs.isEmpty {
                    LabeledContent("diag.resolved_ips") {
                        Text(dns.lastResolvedIPs.joined(separator: ", "))
                            .font(.caption.monospaced())
                            .multilineTextAlignment(.trailing)
                            .lineLimit(3)
                    }
                }
                if let err = dns.lastError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
            }

            Section("diag.actions") {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("diag.refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await forceReinstall() }
                } label: {
                    Label("diag.force_reinstall", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    Task { await forceRemove() }
                } label: {
                    Label("diag.force_remove", systemImage: "trash")
                }

                Button {
                    Task { await testBackend() }
                } label: {
                    Label("diag.test_backend", systemImage: "network")
                }

                if let r = healthCheckResult { Text(r).font(.footnote).foregroundStyle(.secondary) }
                if let r = dohCheckResult { Text(r).font(.footnote).foregroundStyle(.secondary) }
            }

            Section("diag.recent_log") {
                if log.entries.isEmpty {
                    Text("diag.no_log").foregroundStyle(.secondary)
                } else {
                    ForEach(log.entries.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.tag)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.date.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(entry.message)
                                .font(.caption.monospaced())
                                .foregroundStyle(color(for: entry.level))
                        }
                    }
                }
                Button("diag.clear_log") { log.clear() }
                    .disabled(log.entries.isEmpty)
            }
        }
        .navigationTitle("diag.title")
        .task { await refresh() }
        .refreshable { await refresh() }
        .overlay {
            if working {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().scaleEffect(1.5)
            }
        }
    }

    private var urlMismatch: Bool {
        guard let expected = expectedDohURL?.absoluteString,
              let installed = dns.currentServerURL?.absoluteString else { return false }
        return expected != installed
    }

    private func refresh() async {
        working = true; defer { working = false }
        await dns.refresh()
    }

    private func forceRemove() async {
        working = true; defer { working = false }
        do {
            try await dns.disable()
        } catch {
            log.error("DIAG", "force-remove failed: \(error.localizedDescription)")
        }
    }

    private func forceReinstall() async {
        guard let url = expectedDohURL else {
            log.warn("DIAG", "no DoH URL available")
            return
        }
        working = true; defer { working = false }
        do {
            try await dns.reinstall(dohURL: url)
        } catch {
            log.error("DIAG", "force-reinstall failed: \(error.localizedDescription)")
        }
    }

    private func testBackend() async {
        working = true; defer { working = false }
        healthCheckResult = nil
        dohCheckResult = nil

        // /healthz
        do {
            let (data, response) = try await URLSession.shared.data(from: Constants.apiBaseURL.appendingPathComponent("healthz"))
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            healthCheckResult = "healthz: HTTP \(code) — \(body)"
            log.info("DIAG", "healthz HTTP \(code) body=\(body)")
        } catch {
            healthCheckResult = "healthz: ERR \(error.localizedDescription)"
            log.error("DIAG", "healthz failed: \(error.localizedDescription)")
        }

        // DoH endpoint (uses HTTP only, doesn't actually go through the system DNS resolver)
        guard let url = expectedDohURL else {
            dohCheckResult = "no DoH URL"
            return
        }
        // example.com A record, RFC 8484 base64url
        let testQuery = "AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE"
        let dohURL = URL(string: "\(url.absoluteString)?dns=\(testQuery)")!
        var req = URLRequest(url: dohURL)
        req.setValue("application/dns-message", forHTTPHeaderField: "accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            dohCheckResult = "DoH: HTTP \(code), \(data.count) bytes"
            log.info("DIAG", "DoH endpoint HTTP \(code) bytes=\(data.count)")
        } catch {
            dohCheckResult = "DoH: ERR \(error.localizedDescription)"
            log.error("DIAG", "DoH endpoint failed: \(error.localizedDescription)")
        }
    }

    private func color(for level: AppLog.Level) -> Color {
        switch level {
        case .info: return .primary
        case .warn: return .orange
        case .error: return .red
        }
    }
}
