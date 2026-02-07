import Foundation

/// Probes Claude API with a minimal message request to extract rate limit headers.
/// This is the fallback when OAuth `/api/oauth/usage` fails due to missing `user:profile` scope.
/// The `user:inference` scope token can still hit `/v1/messages`, and the response headers
/// contain `anthropic-ratelimit-unified-*` fields with usage data.
///
/// Reference: CodexBar (MIT) — ClaudeStatusProbe pattern.
final class ClaudeStatusProbe {
    static let shared = ClaudeStatusProbe()

    private let messagesURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let probeModel = "claude-sonnet-4-20250514"

    private let cooldownInterval: TimeInterval = 300

    private var lastProbeDate: Date?
    private var lastProbeResult: ProbeResult?

    private init() {}

    // MARK: - Public

    struct ProbeResult {
        let fiveMinuteUtilization: Double?  // maps to 5-hour window
        let dailyUtilization: Double?       // maps to 7-day window
        let fiveMinuteReset: Date?
        let dailyReset: Date?
        let timestamp: Date
    }

    func probe(accessToken: String) async throws -> ProbeResult {
        if let cached = lastProbeResult,
           let lastDate = lastProbeDate,
           Date().timeIntervalSince(lastDate) < cooldownInterval {
            print("📊 ClaudeStatusProbe: returning cached result (cooldown)")
            return cached
        }

        print("📊 ClaudeStatusProbe: sending minimal probe request...")

        guard let url = URL(string: messagesURL) else {
            throw ProbeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // CRITICAL: Use Bearer auth only. Do NOT include x-api-key header.
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("interleaved-thinking-2025-05-14", forHTTPHeaderField: "anthropic-beta")
        request.setValue("AIUsageMonitor/1.0", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "model": probeModel,
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "."]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProbeError.invalidResponse
        }

        let result = parseRateLimitHeaders(from: httpResponse)

        if result.fiveMinuteUtilization != nil || result.dailyUtilization != nil {
            lastProbeResult = result
            lastProbeDate = Date()
            print("📊 ClaudeStatusProbe: success — 5h: \(result.fiveMinuteUtilization.map { "\($0)%" } ?? "n/a"), 7d: \(result.dailyUtilization.map { "\($0)%" } ?? "n/a")")
        } else {
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                print("📊 ClaudeStatusProbe: auth error (\(httpResponse.statusCode)), no rate limit headers")
                throw ProbeError.authError(httpResponse.statusCode)
            }
            print("📊 ClaudeStatusProbe: no rate limit headers in response (status: \(httpResponse.statusCode))")
            throw ProbeError.noRateLimitHeaders
        }

        return result
    }

    func clearCache() {
        lastProbeResult = nil
        lastProbeDate = nil
    }

    // MARK: - Private

    private func parseRateLimitHeaders(from response: HTTPURLResponse) -> ProbeResult {
        let headers = response.allHeaderFields

        let fiveMinUtil = headerDoubleValue(headers, key: "anthropic-ratelimit-unified-five-minute-utilization")
        let dailyUtil = headerDoubleValue(headers, key: "anthropic-ratelimit-unified-daily-utilization")
        let fiveMinReset = headerDateValue(headers, key: "anthropic-ratelimit-unified-five-minute-reset")
        let dailyReset = headerDateValue(headers, key: "anthropic-ratelimit-unified-daily-reset")

        return ProbeResult(
            fiveMinuteUtilization: fiveMinUtil,
            dailyUtilization: dailyUtil,
            fiveMinuteReset: fiveMinReset,
            dailyReset: dailyReset,
            timestamp: Date()
        )
    }

    private func headerDoubleValue(_ headers: [AnyHashable: Any], key: String) -> Double? {
        if let value = headers[key] as? String, let d = Double(value) {
            return d
        }
        let lowerKey = key.lowercased()
        for (k, v) in headers {
            if let kStr = k as? String, kStr.lowercased() == lowerKey,
               let vStr = v as? String, let d = Double(vStr) {
                return d
            }
        }
        return nil
    }

    private func headerDateValue(_ headers: [AnyHashable: Any], key: String) -> Date? {
        var rawValue: String?

        if let value = headers[key] as? String {
            rawValue = value
        } else {
            let lowerKey = key.lowercased()
            for (k, v) in headers {
                if let kStr = k as? String, kStr.lowercased() == lowerKey,
                   let vStr = v as? String {
                    rawValue = vStr
                    break
                }
            }
        }

        guard let raw = rawValue else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

// MARK: - Errors

enum ProbeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noRateLimitHeaders
    case authError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid probe URL"
        case .invalidResponse:
            return "Invalid response from probe"
        case .noRateLimitHeaders:
            return "No rate limit headers in probe response"
        case .authError(let code):
            return "Probe auth error (\(code))"
        }
    }
}
