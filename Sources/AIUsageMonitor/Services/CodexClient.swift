import Foundation

class CodexClient: BaseAPIClient, AIServiceAPI {
    private let codexHome: String

    override init(config: ServiceConfig) {
        // CODEX_HOME defaults to ~/.codex
        self.codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? NSHomeDirectory() + "/.codex"
        super.init(config: config)
    }

    // MARK: - AIServiceAPI

    func fetchUsage() async throws -> UsageData {
        // Try to read local session logs
        let sessionStats = try await analyzeLocalSessions()

        return UsageData(
            tokensUsed: sessionStats.totalTokens,
            tokensLimit: sessionStats.estimatedLimit,
            inputTokens: sessionStats.inputTokens,
            outputTokens: sessionStats.outputTokens,
            periodStart: sessionStats.periodStart,
            periodEnd: sessionStats.periodEnd,
            resetDate: sessionStats.resetDate,
            sevenDayResetDate: sessionStats.sevenDayResetDate,
            currentCost: sessionStats.estimatedCost,
            projectedCost: nil,
            currency: "USD",
            tier: sessionStats.tier,
            lastUpdated: Date(),
            fiveHourUsage: sessionStats.fiveHourUsagePercent,
            sevenDayUsage: sessionStats.sevenDayUsagePercent
        )
    }

    // MARK: - Local Session Analysis

    private struct SessionStats {
        var totalTokens: Int64 = 0
        var inputTokens: Int64 = 0
        var outputTokens: Int64 = 0
        var messageCount: Int = 0
        var sessionCount: Int = 0
        var periodStart: Date
        var periodEnd: Date
        var resetDate: Date
        var sevenDayResetDate: Date?
        var estimatedLimit: Int64 = 225  // Default Plus limit (messages)
        var estimatedCost: Decimal = 0
        var tier: String = "Codex"
        var fiveHourUsagePercent: Double?
        var sevenDayUsagePercent: Double?
    }

    private func analyzeLocalSessions() async throws -> SessionStats {
        let now = Date()
        let calendar = Calendar.current

        // 5-hour window for usage calculation
        let fiveHoursAgo = calendar.date(byAdding: .hour, value: -5, to: now)!

        // Next reset (rolling 5-hour window)
        let nextReset = calendar.date(byAdding: .hour, value: 5, to: now)!

        // 7-day rolling window reset
        let sevenDayReset = calendar.date(byAdding: .day, value: 7, to: now)!

        var stats = SessionStats(
            periodStart: fiveHoursAgo,
            periodEnd: now,
            resetDate: nextReset,
            sevenDayResetDate: sevenDayReset
        )

        // Find session files from the last 24 hours to get recent rate_limits
        let sessionsPath = "\(codexHome)/sessions"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sessionsPath) else {
            stats.tier = "Codex (No sessions)"
            return stats
        }

        // Get recent session files (last 24 hours to find latest rate_limits)
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now)!
        let sessionFiles = try findRecentSessionFiles(
            in: sessionsPath,
            since: oneDayAgo
        )

        stats.sessionCount = sessionFiles.count

        // Parse each session file, keeping the most recent rate_limits
        var latestPrimaryPercent: Double?
        var latestSecondaryPercent: Double?
        var latestPrimaryResetTime: Date?
        var latestSecondaryResetTime: Date?
        var latestPlanType: String?

        for filePath in sessionFiles {
            if let sessionData = parseSessionFile(at: filePath) {
                stats.totalTokens += sessionData.tokens
                stats.inputTokens += sessionData.inputTokens
                stats.outputTokens += sessionData.outputTokens
                stats.messageCount += sessionData.messageCount

                // Keep the most recent rate_limits data
                if let primary = sessionData.primaryUsedPercent {
                    latestPrimaryPercent = primary
                }
                if let secondary = sessionData.secondaryUsedPercent {
                    latestSecondaryPercent = secondary
                }
                if let resetTime = sessionData.primaryResetTime {
                    latestPrimaryResetTime = resetTime
                }
                if let resetTime = sessionData.secondaryResetTime {
                    latestSecondaryResetTime = resetTime
                }
                if let plan = sessionData.planType {
                    latestPlanType = plan
                }
            }
        }

        // Use rate_limits from session logs if available
        if let primary = latestPrimaryPercent {
            stats.fiveHourUsagePercent = primary
        }
        if let secondary = latestSecondaryPercent {
            stats.sevenDayUsagePercent = secondary
        }

        // Use actual reset times from session logs if available
        if let resetTime = latestPrimaryResetTime {
            stats.resetDate = resetTime
        }
        if let resetTime = latestSecondaryResetTime {
            stats.sevenDayResetDate = resetTime
        }

        // Determine tier from plan type or heuristics
        if let plan = latestPlanType {
            stats.tier = "Codex \(plan.capitalized)"
        } else {
            stats.tier = detectTier(messageCount: stats.messageCount)
        }

        // Set limits based on tier
        switch stats.tier.lowercased() {
        case let t where t.contains("pro"):
            stats.estimatedLimit = 1500
        default:
            stats.estimatedLimit = 225
        }

        // Fallback: calculate usage from message count if no rate_limits
        if stats.fiveHourUsagePercent == nil {
            let messageLimit = Double(stats.estimatedLimit)
            stats.fiveHourUsagePercent = min(100, Double(stats.messageCount) / messageLimit * 100)
        }

        // Estimate cost (~5 credits per local task, $0.01 per credit)
        stats.estimatedCost = Decimal(stats.messageCount) * Decimal(0.05)

        return stats
    }

    private func findRecentSessionFiles(in path: String, since date: Date) throws -> [String] {
        let fileManager = FileManager.default
        var sessionFiles: [(path: String, modDate: Date)] = []

        // Walk through YYYY/MM/DD structure
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "jsonl" {
                // Check modification date
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   modDate >= date {
                    sessionFiles.append((fileURL.path, modDate))
                }
            }
        }

        // Sort by modification date (oldest first, so newest is processed last)
        return sessionFiles.sorted { $0.modDate < $1.modDate }.map { $0.path }
    }

    private struct SessionData {
        var tokens: Int64 = 0
        var inputTokens: Int64 = 0
        var outputTokens: Int64 = 0
        var messageCount: Int = 0
        var primaryUsedPercent: Double?  // 5-hour window
        var secondaryUsedPercent: Double?  // 7-day window
        var primaryResetTime: Date?  // 5-hour reset time
        var secondaryResetTime: Date?  // 7-day reset time
        var planType: String?
    }

    private func parseSessionFile(at path: String) -> SessionData? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        var data = SessionData()
        let lines = content.components(separatedBy: .newlines)

        for line in lines where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Check for event_msg wrapper
            let payload: [String: Any]
            if let eventPayload = event["payload"] as? [String: Any] {
                payload = eventPayload
            } else {
                payload = event
            }

            // Count messages (turn.completed events)
            if let type = payload["type"] as? String {
                if type == "turn.completed" {
                    data.messageCount += 1
                }

                // Parse token_count events with rate_limits
                if type == "token_count" {
                    // Extract rate limits (most valuable data!)
                    if let rateLimits = payload["rate_limits"] as? [String: Any] {
                        if let primary = rateLimits["primary"] as? [String: Any] {
                            if let usedPercent = primary["used_percent"] as? Double {
                                data.primaryUsedPercent = usedPercent
                            }
                            // Parse reset time (Unix timestamp)
                            if let resetTimestamp = primary["resets_at"] as? Double {
                                data.primaryResetTime = Date(timeIntervalSince1970: resetTimestamp)
                            } else if let resetTimestamp = primary["resets_at"] as? Int {
                                data.primaryResetTime = Date(timeIntervalSince1970: Double(resetTimestamp))
                            }
                        }
                        if let secondary = rateLimits["secondary"] as? [String: Any] {
                            if let usedPercent = secondary["used_percent"] as? Double {
                                data.secondaryUsedPercent = usedPercent
                            }
                            if let resetTimestamp = secondary["resets_at"] as? Double {
                                data.secondaryResetTime = Date(timeIntervalSince1970: resetTimestamp)
                            } else if let resetTimestamp = secondary["resets_at"] as? Int {
                                data.secondaryResetTime = Date(timeIntervalSince1970: Double(resetTimestamp))
                            }
                        }
                        if let planType = rateLimits["plan_type"] as? String {
                            data.planType = planType
                        }
                    }

                    // Extract token usage
                    if let info = payload["info"] as? [String: Any],
                       let tokenUsage = info["total_token_usage"] as? [String: Any] {
                        if let input = tokenUsage["input_tokens"] as? Int {
                            data.inputTokens = Int64(input)
                        }
                        if let output = tokenUsage["output_tokens"] as? Int {
                            data.outputTokens = Int64(output)
                        }
                        if let total = tokenUsage["total_tokens"] as? Int {
                            data.tokens = Int64(total)
                        }
                    }
                }
            }
        }

        // If no token counts, estimate from messages
        if data.tokens == 0 && data.messageCount > 0 {
            // Rough estimate: ~2000 tokens per message average
            data.tokens = Int64(data.messageCount) * 2000
            data.inputTokens = Int64(Double(data.tokens) * 0.3)
            data.outputTokens = Int64(Double(data.tokens) * 0.7)
        }

        return data
    }

    private func detectTier(messageCount: Int) -> String {
        // Pro users typically have higher limits
        // This is a heuristic - could be improved with config file detection
        let configPath = "\(codexHome)/config.toml"
        if let config = try? String(contentsOfFile: configPath, encoding: .utf8) {
            if config.contains("pro") || config.contains("Pro") {
                return "Codex Pro"
            }
        }

        return "Codex Plus"
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
