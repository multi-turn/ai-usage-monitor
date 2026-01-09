import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName = "com.aiusagemonitor"

    // Cache for Claude Code credentials to avoid multiple Keychain prompts
    private var cachedClaudeCredentials: ClaudeCodeCredentials?
    private var credentialsCacheTime: Date?
    private let cacheValidityDuration: TimeInterval = 300  // 5 minutes

    private init() {}

    private func debugLog(_ message: String) {
        let logFile = "/tmp/aiusagemonitor.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = FileHandle(forWritingAtPath: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
        print(message)
    }

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(for key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.retrieveFailed(status)
        }

        return value
    }

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func exists(for key: String) -> Bool {
        do {
            _ = try retrieve(for: key)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Claude Code Credentials

    /// Reads Claude Code OAuth credentials from system Keychain
    /// Uses single query + caching to minimize Keychain access prompts
    func getClaudeCodeCredentials() -> ClaudeCodeCredentials? {
        debugLog("📋 getClaudeCodeCredentials called")

        // Return cached credentials if still valid
        if let cached = cachedClaudeCredentials,
           let cacheTime = credentialsCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheValidityDuration,
           !cached.isExpired {
            debugLog("📦 Returning cached credentials")
            return cached
        }

        debugLog("🔍 Fetching from Keychain...")
        // Single Keychain query to get all Claude Code credentials at once
        let credentials = getAllClaudeCodeCredentials()

        // Find the best (non-expired, latest expiry) credential
        var bestCredentials: ClaudeCodeCredentials? = nil
        var bestExpiresAt: Int64 = 0

        for creds in credentials {
            let expiresAt = creds.expiresAtMs ?? 0
            if !creds.isExpired && expiresAt > bestExpiresAt {
                bestCredentials = creds
                bestExpiresAt = expiresAt
            } else if bestCredentials == nil {
                bestCredentials = creds
                bestExpiresAt = expiresAt
            }
        }

        // Cache the result
        cachedClaudeCredentials = bestCredentials
        credentialsCacheTime = Date()

        return bestCredentials
    }

    /// Clears the cached credentials (call after token refresh)
    func clearCredentialsCache() {
        cachedClaudeCredentials = nil
        credentialsCacheTime = nil
    }

    /// Single Keychain query for Claude Code credentials
    private func getAllClaudeCodeCredentials() -> [ClaudeCodeCredentials] {
        // Query specifically for "Claude Code-credentials" service
        // This makes only ONE Keychain access with minimal permissions
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        debugLog("🔑 Keychain query status: \(status)")

        guard status == errSecSuccess else {
            debugLog("❌ Keychain query failed: \(status)")
            return []
        }

        guard let data = result as? Data else {
            debugLog("❌ Keychain data not found or wrong type")
            return []
        }

        guard let creds = parseCredentials(from: data) else {
            debugLog("❌ Failed to parse credentials from data (\(data.count) bytes)")
            return []
        }

        debugLog("✅ Credentials loaded successfully, expires: \(creds.expiresAt?.description ?? "unknown")")
        return [creds]
    }

    private func parseCredentials(from data: Data) -> ClaudeCodeCredentials? {
        do {
            // The JSON is wrapped in {"claudeAiOauth": {...}}
            let wrapper = try JSONDecoder().decode(ClaudeCodeCredentialsWrapper.self, from: data)
            return wrapper.claudeAiOauth
        } catch {
            // Try direct decode as fallback
            return try? JSONDecoder().decode(ClaudeCodeCredentials.self, from: data)
        }
    }
}

struct ClaudeCodeCredentialsWrapper: Codable {
    let claudeAiOauth: ClaudeCodeCredentials
}

struct ClaudeCodeCredentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAtMs: Int64?  // Milliseconds since epoch
    let idToken: String?
    let rateLimitTier: String?

    enum CodingKeys: String, CodingKey {
        case accessToken      // JSON uses camelCase: "accessToken"
        case refreshToken     // JSON uses camelCase: "refreshToken"
        case expiresAtMs = "expiresAt"  // JSON key is "expiresAt"
        case idToken          // JSON uses camelCase: "idToken"
        case rateLimitTier    // JSON uses camelCase: "rateLimitTier"
    }

    var expiresAt: Date? {
        guard let ms = expiresAtMs else { return nil }
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }

    var willExpireSoon: Bool {
        guard let expiresAt = expiresAt else { return false }
        // Consider expired if less than 5 minutes remaining
        return Date().addingTimeInterval(300) >= expiresAt
    }
}

// MARK: - Token Refresh

extension KeychainManager {
    /// Attempts to refresh the Claude Code OAuth token using the refresh token
    func refreshClaudeCodeToken() async throws -> ClaudeCodeCredentials {
        guard let credentials = getClaudeCodeCredentials() else {
            throw TokenRefreshError.noCredentials
        }

        guard let refreshToken = credentials.refreshToken else {
            throw TokenRefreshError.noRefreshToken
        }

        let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "claude-code"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenRefreshError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Token refresh failed: \(httpResponse.statusCode) - \(message)")
            throw TokenRefreshError.refreshFailed(httpResponse.statusCode, message)
        }

        // Parse the new token response
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenRefreshResponse.self, from: data)

        // Update Keychain with new credentials
        let newCredentials = ClaudeCodeCredentials(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAtMs: Int64(Date().timeIntervalSince1970 * 1000) + Int64(tokenResponse.expiresIn * 1000),
            idToken: tokenResponse.idToken,
            rateLimitTier: credentials.rateLimitTier
        )

        try updateClaudeCodeCredentials(newCredentials)

        // Update cache with new credentials
        cachedClaudeCredentials = newCredentials
        credentialsCacheTime = Date()

        print("✅ Token refreshed successfully")
        return newCredentials
    }

    /// Updates Claude Code credentials in Keychain
    private func updateClaudeCodeCredentials(_ credentials: ClaudeCodeCredentials) throws {
        let wrapper = ClaudeCodeCredentialsWrapper(claudeAiOauth: credentials)
        let data = try JSONEncoder().encode(wrapper)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials"
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            var newQuery = query
            newQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case idToken = "id_token"
    }
}

enum TokenRefreshError: LocalizedError {
    case noCredentials
    case noRefreshToken
    case invalidResponse
    case refreshFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No Claude Code credentials found"
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidResponse:
            return "Invalid response from token server"
        case .refreshFailed(let code, let message):
            return "Token refresh failed (\(code)): \(message)"
        }
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value"
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}
