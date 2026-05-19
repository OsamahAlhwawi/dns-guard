import Foundation

@MainActor
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let pinner = CertificatePinner()

    private var accessToken: String?
    private var refreshTask: Task<String?, Error>?

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config, delegate: pinner, delegateQueue: nil)
        self.accessToken = KeychainService.get(.accessToken)
    }

    // MARK: - Tokens

    var hasSession: Bool { accessToken != nil }

    func setTokens(access: String, refresh: String?) {
        accessToken = access
        KeychainService.set(access, for: .accessToken)
        if let refresh { KeychainService.set(refresh, for: .refreshToken) }
    }

    func clearTokens() {
        accessToken = nil
        KeychainService.clearAll()
    }

    // MARK: - Bodies

    private struct RegisterBody: Encodable {
        let username: String
        let password: String
        let full_name: String?
        let email: String?
    }

    private struct LoginBody: Encodable {
        let username: String
        let password: String
    }

    private struct RefreshBody: Encodable {
        let refresh_token: String
    }

    private struct RefreshResp: Decodable {
        let access_token: String
        let expires_in: Int
    }

    // MARK: - Public

    func register(username: String, password: String, fullName: String?, email: String?) async throws -> RegisterResponse {
        try await send(method: "POST", path: "/v1/auth/register",
                       body: RegisterBody(username: username, password: password, full_name: fullName, email: email),
                       requiresAuth: false)
    }

    func login(username: String, password: String) async throws -> AuthTokens {
        let tokens: AuthTokens = try await send(method: "POST", path: "/v1/auth/login",
                                                body: LoginBody(username: username, password: password),
                                                requiresAuth: false)
        setTokens(access: tokens.access_token, refresh: tokens.refresh_token)
        return tokens
    }

    func logout() async throws {
        _ = try await send(method: "POST", path: "/v1/auth/logout", body: EmptyBody?.none) as Empty
        clearTokens()
    }

    func me() async throws -> User {
        try await send(method: "GET", path: "/v1/user/profile", body: EmptyBody?.none)
    }

    func dnsStatus() async throws -> DNSStatusResponse {
        try await send(method: "GET", path: "/v1/dns/status", body: EmptyBody?.none)
    }

    func dnsConfig() async throws -> DNSConfigResponse {
        try await send(method: "GET", path: "/v1/dns/config", body: EmptyBody?.none)
    }

    func todayStats() async throws -> TodayStats {
        try await send(method: "GET", path: "/v1/stats/today", body: EmptyBody?.none)
    }

    func history(period: String) async throws -> HistoryResponse {
        try await send(method: "GET", path: "/v1/stats/history?period=\(period)", body: EmptyBody?.none)
    }

    // MARK: - Admin

    func adminListUsers(pendingOnly: Bool = false) async throws -> [User] {
        let path = pendingOnly ? "/v1/admin/users?pending=1" : "/v1/admin/users"
        let resp: AdminUsersResponse = try await send(method: "GET", path: path, body: EmptyBody?.none)
        return resp.users
    }

    func adminListPending() async throws -> [User] {
        let resp: AdminUsersResponse = try await send(method: "GET", path: "/v1/admin/pending", body: EmptyBody?.none)
        return resp.users
    }

    func adminUpdateUser(id: Int, patch: AdminUserUpdate) async throws -> User {
        try await send(method: "PATCH", path: "/v1/admin/users/\(id)", body: patch)
    }

    func adminDeleteUser(id: Int) async throws {
        _ = try await send(method: "DELETE", path: "/v1/admin/users/\(id)", body: EmptyBody?.none) as Empty
    }

    func adminUserStats(id: Int) async throws -> AdminUserStatsResponse {
        try await send(method: "GET", path: "/v1/admin/users/\(id)/stats", body: EmptyBody?.none)
    }

    func adminUserLogs(id: Int, limit: Int = 100) async throws -> QueryLogResponse {
        try await send(method: "GET", path: "/v1/admin/users/\(id)/logs?limit=\(limit)", body: EmptyBody?.none)
    }

    func adminOverview() async throws -> AdminOverview {
        try await send(method: "GET", path: "/v1/admin/stats/overview", body: EmptyBody?.none)
    }

    // MARK: - Core

    struct Empty: Codable {}
    private struct EmptyBody: Encodable {}

    private func send<T: Decodable, B: Encodable>(
        method: String,
        path: String,
        body: B?,
        requiresAuth: Bool = true,
        retryOn401: Bool = true
    ) async throws -> T {
        guard let url = makeURL(path: path) else {
            throw APIError.transport("invalid path")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)
        }
        if requiresAuth, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch URLError.notConnectedToInternet {
            throw APIError.noNetwork
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("invalid response")
        }

        switch http.statusCode {
        case 200..<300:
            if data.isEmpty, T.self == Empty.self {
                return Empty() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        case 400:
            throw APIError.validation(decodeErrorMessage(data) ?? String(localized: "error.bad_request"))
        case 401:
            if requiresAuth, retryOn401, try await refreshAccessToken() != nil {
                return try await send(method: method, path: path, body: body, requiresAuth: requiresAuth, retryOn401: false)
            }
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409:
            throw APIError.conflict(decodeErrorMessage(data) ?? "")
        default:
            throw APIError.server(http.statusCode, decodeErrorMessage(data) ?? "")
        }
    }

    private func makeURL(path: String) -> URL? {
        var s = Constants.apiBaseURL.absoluteString
        if s.hasSuffix("/") { s.removeLast() }
        let p = path.hasPrefix("/") ? path : "/" + path
        return URL(string: s + p)
    }

    private func decodeErrorMessage(_ data: Data) -> String? {
        (try? decoder.decode(ServerErrorPayload.self, from: data))?.error
    }

    private func refreshAccessToken() async throws -> String? {
        if let task = refreshTask { return try await task.value }
        let task = Task<String?, Error> { [weak self] in
            defer { self?.refreshTask = nil }
            guard let self else { return nil }
            guard let refresh = KeychainService.get(.refreshToken) else { return nil }
            do {
                let resp: RefreshResp = try await self.send(
                    method: "POST",
                    path: "/v1/auth/refresh",
                    body: RefreshBody(refresh_token: refresh),
                    requiresAuth: false,
                    retryOn401: false
                )
                self.accessToken = resp.access_token
                KeychainService.set(resp.access_token, for: .accessToken)
                return resp.access_token
            } catch {
                self.clearTokens()
                return nil
            }
        }
        refreshTask = task
        return try await task.value
    }
}
