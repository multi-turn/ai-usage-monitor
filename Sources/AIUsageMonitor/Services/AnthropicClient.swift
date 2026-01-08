import Foundation

class AnthropicClient: BaseAPIClient, AIServiceAPI {
    private let baseURL = "https://api.anthropic.com"
    private let apiVersion = "2023-06-01"

    func fetchUsage() async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        // Anthropic doesn't have a usage API - use locally tracked data
        let localUsage = getLocalUsage()
        return convertToUsageData(localUsage: localUsage)
    }

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

    private func convertToUsageData(localUsage: (input: Int, output: Int, limit: Int)) -> UsageData {
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

        let tier: String
        if localUsage.limit >= 1_000_000 {
            tier = "Scale Tier"
        } else if localUsage.limit >= 100_000 {
            tier = "Build Tier"
        } else {
            tier = "Free Tier"
        }

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
            tier: tier,
            lastUpdated: now
        )
    }
}
