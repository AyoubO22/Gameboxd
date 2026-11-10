//
//  Backend.swift
//  Gameboxd
//
//  The Gameboxd server (PocketBase, see server/): accounts, the social network, the
//  public library mirror, and the IGDB / Steam proxies that keep API keys off the phone.
//  Plain HTTP + JSON; the session token is kept in the Keychain.
//

import Foundation

enum BackendConfig {
    /// SERVER_HOST in Secrets.xcconfig: host and optional port, without "http://" because
    /// "//" starts a comment in .xcconfig files. A host with a port (the Mac on the Wi-Fi,
    /// e.g. "my-mac.local:8090") is reached over plain http; any other host over https.
    static var url: URL? {
        guard let host = value("SERVER_HOST"), !host.isEmpty else { return nil }
        return URL(string: "\(host.contains(":") ? "http" : "https")://\(host)")
    }
    static var isConfigured: Bool { url != nil }

    private static func value(_ key: String) -> String? {
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty { return v }
        return ProcessInfo.processInfo.environment[key]
    }
}

/// An answer from the server other than 2xx. `fields` holds PocketBase's validation codes
/// by field (e.g. "email": "validation_not_unique").
nonisolated struct BackendError: LocalizedError {
    let status: Int
    let message: String
    var fields: [String: String] = [:]

    var errorDescription: String? { "\(status) \(message) \(fields)" }
}

final class Backend {
    static let shared = Backend()

    private let session = URLSession(configuration: .default)

    /// Auth token of the signed-in player (nil when signed out).
    /// Read from the Keychain once, then kept in memory: every request needs it.
    var token: String? {
        get {
            if !tokenLoaded {
                cachedToken = TokenStore.load()
                tokenLoaded = true
            }
            return cachedToken
        }
        set {
            cachedToken = newValue
            tokenLoaded = true
            if let newValue { TokenStore.save(newValue) } else { TokenStore.clear() }
        }
    }
    private var cachedToken: String?
    private var tokenLoaded = false

    // MARK: - Requests

    func send<T: Decodable>(_ method: String, _ path: String, query: [String: String] = [:], body: (any Encodable)? = nil) async throws -> T {
        let data = try await raw(method, path, query: query, body: body)
        return try Self.decoder.decode(T.self, from: Self.withoutEmptyValues(data))
    }

    func send(_ method: String, _ path: String, query: [String: String] = [:], body: (any Encodable)? = nil) async throws {
        _ = try await raw(method, path, query: query, body: body)
    }

    /// Records of a collection, up to `limit`, page after page.
    func list<T: Decodable>(_ collection: String, filter: String? = nil, sort: String? = nil,
                            expand: String? = nil, limit: Int = 500) async throws -> [T] {
        var items: [T] = []
        var page = 1
        while items.count < limit {
            var query = ["page": String(page), "perPage": String(min(limit - items.count, 500)), "skipTotal": "1"]
            query["filter"] = filter
            query["sort"] = sort
            query["expand"] = expand
            let result: Page<T> = try await send("GET", "/api/collections/\(collection)/records", query: query)
            items += result.items
            if result.items.count < result.perPage { break }
            page += 1
        }
        return items
    }

    func count(_ collection: String, filter: String) async throws -> Int {
        let result: Page<Empty> = try await send("GET", "/api/collections/\(collection)/records",
                                                 query: ["filter": filter, "perPage": "1", "fields": "id"])
        return result.totalItems ?? 0
    }

    /// A value inside a filter: the app only filters by ids and pseudos, but quotes are
    /// escaped anyway so input can't change the filter.
    static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// `field = "a" || field = "b"`, for a set of ids.
    static func any(_ field: String, in values: [String]) -> String {
        "(" + values.map { "\(field) = \(quoted($0))" }.joined(separator: " || ") + ")"
    }

    private func raw(_ method: String, _ path: String, query: [String: String], body: (any Encodable)?) async throws -> Data {
        guard let base = BackendConfig.url, var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw AccountError.notConfigured
        }
        // Strict encoding: filters hold "&", "=" and "+", which a query string would misread.
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        if !query.isEmpty {
            components.percentEncodedQueryItems = query.sorted { $0.key < $1.key }.map {
                URLQueryItem(name: $0.key, value: $0.value.addingPercentEncoding(withAllowedCharacters: safe))
            }
        }
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let answer = try? JSONDecoder().decode(ErrorAnswer.self, from: data)
            throw BackendError(status: status, message: answer?.message ?? "",
                               fields: (answer?.data ?? [:]).compactMapValues(\.code))
        }
        return data
    }

    // MARK: - JSON

    private nonisolated struct Page<T: Decodable>: Decodable {
        let items: [T]
        let perPage: Int
        let totalItems: Int?
    }
    private nonisolated struct Empty: Decodable {}
    private nonisolated struct ErrorAnswer: Decodable {
        struct Field: Decodable { let code: String? }
        let message: String?
        let data: [String: Field]?
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// PocketBase writes dates as "2026-11-09 20:53:32.073Z".
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "date \(text)"))
        }
        return decoder
    }()

    /// PocketBase sends "" for an empty text or date where the app expects nil.
    static func withoutEmptyValues(_ data: Data) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return data }
        func clean(_ value: Any) -> Any {
            if let dict = value as? [String: Any] {
                return dict.filter { !(($0.value as? String)?.isEmpty ?? false) }.mapValues(clean)
            }
            if let array = value as? [Any] { return array.map(clean) }
            return value
        }
        return (try? JSONSerialization.data(withJSONObject: clean(json), options: [.fragmentsAllowed])) ?? data
    }
}

// MARK: - Token storage (Keychain, this device only)

private enum TokenStore {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.gameboxd.server",
         kSecAttrAccount as String: "token"]
    }

    static func load() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

extension UUID {
    /// The server writes ids in lowercase; Swift prints them in uppercase.
    nonisolated var serverId: String { uuidString.lowercased() }
}
