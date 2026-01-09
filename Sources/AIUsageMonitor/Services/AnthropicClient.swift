import Foundation

class AnthropicClient: BaseAPIClient, AIServiceAPI {
    private let oauthUsageURL = "https://api.anthropic.com/api/oauth/usage"

    // MARK: - OAuth Usage Response Models

    private struct OAuthUsageResponse: Codable {
        let fiveHour: UsageWindow?
        let sevenDay: UsageWindow?
        let sevenDayOpus: UsageWindow?
        let sevenDaySonnet: UsageWindow?
        let sevenDayOAuthApps: UsageWindow?
        let extraUsage: ExtraUsage?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
            case sevenDayOAuthApps = "seven_day_oauth_apps"
            case extraUsage = "extra_usage"
        }
    }

    private struct UsageWindow: Codable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    private struct ExtraUsage: Codable {
        let monthlyLimitCents: Int?
        let creditsUsedCents: Int?

        enum CodingKeys: String, CodingKey {
            case monthlyLimitCents = "monthly_limit_cents"
            case creditsUsedCents = "credits_used_cents"
        }
    }

    // MARK: - AIServiceAPI

    private func debugLog(_ message: String) {
        let logFile = "/tmp/aiusagemonitor.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [API] \(message)\n"
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
    }

    func fetchUsage() async throws -> UsageData {
        debugLog("📡 fetchUsage called")
        // Try OAuth first (Claude Code credentials from Keychain)
        if var credentials = KeychainManager.shared.getClaudeCodeCredentials() {
            debugLog("✅ Got credentials, token prefix: \(String(credentials.accessToken.prefix(20)))...")
            // Check if token is expired or will expire soon
            if credentials.isExpired || credentials.willExpireSoon {
                print("🔄 Token expired or expiring soon, attempting refresh...")
                do {
                    credentials = try await KeychainManager.shared.refreshClaudeCodeToken()
                    print("✅ Token refreshed automatically")
                } catch {
                    print("⚠️ Auto-refresh failed: \(error.localizedDescription)")
                    // If refresh fails with no refresh token, show helpful message
                    throw APIError.httpError(
                        statusCode: 401,
                        message: "토큰이 만료되었습니다. 터미널에서 'claude'를 실행해주세요."
                    )
                }
            }

            do {
                debugLog("🌐 Calling fetchOAuthUsage...")
                let result = try await fetchOAuthUsage(accessToken: credentials.accessToken, tier: credentials.rateLimitTier)
                debugLog("✅ Got usage: 5h=\(result.fiveHourUsage ?? -1)%, 7d=\(result.sevenDayUsage ?? -1)%")
                return result
            } catch let error as APIError {
                debugLog("❌ API error: \(error)")
                if case .unauthorized = error {
                    // Try one more refresh attempt
                    print("🔄 Got 401, attempting token refresh...")
                    do {
                        let newCredentials = try await KeychainManager.shared.refreshClaudeCodeToken()
                        return try await fetchOAuthUsage(accessToken: newCredentials.accessToken, tier: newCredentials.rateLimitTier)
                    } catch {
                        throw APIError.httpError(
                            statusCode: 401,
                            message: "토큰이 만료되었습니다. 터미널에서 'claude'를 실행해주세요."
                        )
                    }
                }
                throw error
            }
        }

        // Fall back to local tracking if no credentials
        if !config.apiKey.isEmpty {
            let localUsage = getLocalUsage()
            return convertToUsageData(localUsage: localUsage, tier: "Local Tracking")
        }

        throw APIError.missingAPIKey
    }

    // MARK: - OAuth API

    private func fetchOAuthUsage(accessToken: String, tier: String?) async throws -> UsageData {
        guard let url = URL(string: oauthUsageURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("AIUsageMonitor/1.0", forHTTPHeaderField: "User-Agent")

        debugLog("📤 Sending request to \(oauthUsageURL)")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            debugLog("❌ Invalid response type")
            throw APIError.invalidResponse
        }

        debugLog("📥 HTTP \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                debugLog("❌ Unauthorized")
                throw APIError.unauthorized
            }
            let message = String(data: data, encoding: .utf8)
            debugLog("❌ HTTP Error: \(message ?? "unknown")")
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        let usageResponse = try decoder.decode(OAuthUsageResponse.self, from: data)
        debugLog("✅ Decoded response: 5h=\(usageResponse.fiveHour?.utilization ?? -1)")

        return convertOAuthToUsageData(response: usageResponse, tier: tier)
    }

    private func convertOAuthToUsageData(response: OAuthUsageResponse, tier: String?) -> UsageData {
        let now = Date()
        let calendar = Calendar.current

        // Use 5-hour window as primary, fall back to 7-day
        let primaryWindow = response.fiveHour ?? response.sevenDay
        let usagePercentage = primaryWindow?.utilization ?? 0

        let formatter = ISO8601DateFormatter()

        // Parse 5-hour reset date
        var resetDate: Date? = nil
        if let resetsAt = response.fiveHour?.resetsAt {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetDate = formatter.date(from: resetsAt)
            if resetDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                resetDate = formatter.date(from: resetsAt)
            }
        }

        // Parse 7-day reset date
        var sevenDayResetDate: Date? = nil
        if let resetsAt = response.sevenDay?.resetsAt {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            sevenDayResetDate = formatter.date(from: resetsAt)
            if sevenDayResetDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                sevenDayResetDate = formatter.date(from: resetsAt)
            }
        }

        // Calculate period
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        // Estimate tokens from usage percentage (rough estimate based on typical limits)
        let estimatedLimit: Int64 = 1_000_000 // 1M tokens as baseline
        let tokensUsed = Int64(Double(estimatedLimit) * (usagePercentage / 100.0))

        // Calculate cost from extra usage if available
        var currentCost: Decimal = 0
        if let extraUsage = response.extraUsage,
           let creditsUsed = extraUsage.creditsUsedCents {
            currentCost = Decimal(creditsUsed) / 100 // Convert cents to dollars
        }

        // Determine tier name (tier can be like "default_claude_max_5x")
        let tierName: String
        if let t = tier?.lowercased() {
            if t.contains("max") {
                tierName = "Claude Max"
            } else if t.contains("pro") {
                tierName = "Claude Pro"
            } else if t.contains("team") {
                tierName = "Claude Team"
            } else if t.contains("enterprise") {
                tierName = "Claude Enterprise"
            } else if t.contains("free") {
                tierName = "Claude Free"
            } else {
                tierName = tier ?? "Claude"
            }
        } else {
            tierName = "Claude Pro"
        }

        return UsageData(
            tokensUsed: tokensUsed,
            tokensLimit: estimatedLimit,
            inputTokens: nil,
            outputTokens: nil,
            periodStart: startOfMonth,
            periodEnd: endOfMonth,
            resetDate: resetDate ?? endOfMonth,
            sevenDayResetDate: sevenDayResetDate,
            currentCost: currentCost,
            projectedCost: nil,
            currency: "USD",
            tier: tierName,
            lastUpdated: now,
            fiveHourUsage: response.fiveHour?.utilization,
            sevenDayUsage: response.sevenDay?.utilization
        )
    }

    // MARK: - Local Tracking (Fallback)

    private func getLocalUsage() -> (input: Int, output: Int, limit: Int) {
        let key = "anthropic_usage_\(config.id)"
        let usage = UserDefaults.standard.dictionary(forKey: key) ?? [:]

        let input = usage["inputTokens"] as? Int ?? 0
        let output = usage["outputTokens"] as? Int ?? 0
        let limit = usage["tokensLimit"] as? Int ?? 100_000

        return (input, output, limit)
    }

    func trackUsage(inputTokens: Int, outputTokens: Int, tokensLimit: Int? = nil) {
        let key = "anthropic_usage_\(config.id)"
        var usage = UserDefaults.standard.dictionary(forKey: key) ?? [:]

        let totalInput = (usage["inputTokens"] as? Int ?? 0) + inputTokens
        let totalOutput = (usage["outputTokens"] as? Int ?? 0) + outputTokens

        usage["inputTokens"] = totalInput
        usage["outputTokens"] = totalOutput
        if let limit = tokensLimit {
            usage["tokensLimit"] = limit
        }
        usage["lastUpdated"] = Date().timeIntervalSince1970

        UserDefaults.standard.set(usage, forKey: key)
    }

    func resetUsage() {
        let key = "anthropic_usage_\(config.id)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func convertToUsageData(localUsage: (input: Int, output: Int, limit: Int), tier: String) -> UsageData {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let tokensUsed = Int64(localUsage.input + localUsage.output)
        let tokensLimit = Int64(localUsage.limit)

        // Claude pricing (average): $3 per 1M input, $15 per 1M output
        let inputCost = Decimal(localUsage.input) * Decimal(3) / Decimal(1_000_000)
        let outputCost = Decimal(localUsage.output) * Decimal(15) / Decimal(1_000_000)
        let currentCost = inputCost + outputCost

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let projectedCost = currentCost * Decimal(Double(daysInMonth) / Double(max(currentDay, 1)))

        return UsageData(
            tokensUsed: tokensUsed,
            tokensLimit: tokensLimit,
            inputTokens: Int64(localUsage.input),
            outputTokens: Int64(localUsage.output),
            periodStart: startOfMonth,
            periodEnd: endOfMonth,
            resetDate: endOfMonth,
            sevenDayResetDate: nil,
            currentCost: currentCost,
            projectedCost: projectedCost,
            currency: "USD",
            tier: tier,
            lastUpdated: now,
            fiveHourUsage: nil,
            sevenDayUsage: nil
        )
    }
}
