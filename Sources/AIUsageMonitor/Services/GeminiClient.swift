import Foundation

class GeminiClient: BaseAPIClient, AIServiceAPI {
    func fetchUsage() async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        // Gemini doesn't have a usage API - use locally tracked data
        let localUsage = getLocalUsage()
        return convertToUsageData(localUsage: localUsage)
    }

    private func getLocalUsage() -> (input: Int, output: Int) {
        let key = "gemini_usage_\(config.id)"
        let usage = UserDefaults.standard.dictionary(forKey: key) ?? [:]

        let input = usage["inputTokens"] as? Int ?? 0
        let output = usage["outputTokens"] as? Int ?? 0

        return (input, output)
    }

    func trackUsage(inputTokens: Int, outputTokens: Int) {
        let key = "gemini_usage_\(config.id)"
        var usage = UserDefaults.standard.dictionary(forKey: key) ?? [:]

        let totalInput = (usage["inputTokens"] as? Int ?? 0) + inputTokens
        let totalOutput = (usage["outputTokens"] as? Int ?? 0) + outputTokens

        usage["inputTokens"] = totalInput
        usage["outputTokens"] = totalOutput
        usage["lastUpdated"] = Date().timeIntervalSince1970

        UserDefaults.standard.set(usage, forKey: key)
    }

    func resetUsage() {
        let key = "gemini_usage_\(config.id)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func convertToUsageData(localUsage: (input: Int, output: Int)) -> UsageData {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let tokensUsed = Int64(localUsage.input + localUsage.output)
        // Gemini free tier: 1.5M tokens/day = ~45M/month
        let tokensLimit: Int64 = 45_000_000

        // Gemini pricing: $0.125 per 1M input, $0.375 per 1M output (Pro)
        let inputCost = Decimal(localUsage.input) * Decimal(0.125) / Decimal(1_000_000)
        let outputCost = Decimal(localUsage.output) * Decimal(0.375) / Decimal(1_000_000)
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
            currentCost: currentCost,
            projectedCost: projectedCost,
            currency: "USD",
            tier: "Free Tier",
            lastUpdated: now,
            fiveHourUsage: nil,
            sevenDayUsage: nil
        )
    }
}
