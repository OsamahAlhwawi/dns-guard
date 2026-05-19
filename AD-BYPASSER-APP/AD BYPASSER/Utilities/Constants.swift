import Foundation

enum Constants {
    /// JSON API base. Endpoints live under `/v1/*`.
    static let apiBaseURL = URL(string: "https://abs.whao.tech")!

    /// DoH base. The user-specific token is appended at runtime as `/dns-query/<token>`.
    /// Same host as the API by default — split into a subdomain if you want a dedicated vhost.
    static let dnsBaseURL = URL(string: "https://abs.whao.tech")!

    /// Bundle identifier — also used as the keychain service name.
    static let bundleID = "WHAOTECH.AD-BYPASSER"

    /// localizedDescription on the NEDNSSettings profile (shown in Settings UI).
    static let dnsProfileLabel = "DNS Guard"

    /// Fallback servers AdGuard/iOS uses for the DoH endpoint hostname resolution.
    static let dohBootstrapServers = ["1.1.1.1", "9.9.9.9"]

    /// SPKI SHA-256 base64 hashes for certificate pinning. Empty = pinning disabled
    /// (use only during local dev). Populate with `openssl s_client -connect host:443
    /// -showcerts | openssl x509 -pubkey | openssl pkey -pubin -outform der | openssl
    /// dgst -sha256 -binary | base64`.
    static let pinnedSPKIHashes: [String: [String]] = [:]
    // Populate per-host pins like:
    //   "api.example.com": ["base64sha256=", "backup-base64sha256="],
    //   "dns.example.com": ["base64sha256="],

    static let foregroundStatusPollSeconds: TimeInterval = 30
}
