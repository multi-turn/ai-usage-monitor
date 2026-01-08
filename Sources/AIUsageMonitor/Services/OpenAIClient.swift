import Foundation

class OpenAIClient: BaseAPIClient, AIServiceAPI {
    private let baseURL = "https://api.openai.com"

    private struct BillingUsageResponse: Codable {
        let totalUsage: Double
        let dailyCosts: [DailyCost]?

        enum CodingKeys: String, CodingKey {
            case totalUsage = "total_usage"
            case dailyCosts = "daily_costs"
        }

        struct DailyCost: Codable {
            let timestamp: Int
            let lineItems: [LineItem]?

            enum CodingKeys: String, CodingKey {
                case timestamp
                case lineItems = "line_items"
            }

            struct LineItem: Codable {
                let name: String
                let cost: Double
            }
        }
    }

    private struct SubscriptionResponse: Codable {
        let hardLimitUSD: Double?
        let softLimitUSD: Double?
        let systemHardLimitUSD: Double?
        let plan: Plan?

        enum CodingKeys: String, CodingKey {
            case hardLimitUSD = "hard_limit_usd"
            case softLimitUSD = "soft_limit_usd"
            case systemHardLimitUSD = "system_hard_limit_usd"
            case plan
        }

        struct Plan: Codable {
            let title: String?
        }
    }

    func fetchUsage() async throws -> UsageData {
        guard !config.apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        async let usageData = fetchBillingUsage()
        async let subscriptionData = fetchSubscription()

        let (usage, subscription) = try await (usageData, subscriptionData)
        return convertToUsageData(usage: usage, subscription: subscription)
    }

    private func fetchBillingUsage() async throws -> BillingUsageResponse {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startDate = dateFormatter.string(from: startOfMonth)
        let endDate = dateFormatter.string(from: endOfMonth)

        guard let url = URL(string: "\(baseURL)/v1/dashboard/billing/usage?start_date=\(startDate)&end_date=\(endDate)") else {
            throw APIError.invalidURL
        }

        let headers = [
            "Authorization": "Bearer \(config.apiKey)",
            "Content-Type": "application/json"
        ]

        let (data, _) = try await performRequest(url: url, headers: headers)

        do {
            return try JSONDecoder().decode(BillingUsageResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func fetchSubscription() async throws -> SubscriptionResponse {
        guard let url = URL(string: "\(baseURL)/v1/dashboard/billing/subscription") else {
            throw APIError.invalidURL
        }

        let headers = [
            "Authorization": "Bearer \(config.apiKey)",
            "Content-Type": "application/json"
        ]

        let (data, _) = try await performRequest(url: url, headers: headers)

        do {
            return try JSONDecoder().decode(SubscriptionResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func convertToUsageData(usage: BillingUsageResponse, subscription: SubscriptionResponse) -> UsageData {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        let currentCost = Decimal(usage.totalUsage / 100.0)
        let estimatedTokensUsed = Int64(usage.totalUsage * 100)
        let limitUSD = subscription.hardLimitUSD ?? subscription.systemHardLimitUSD ?? 100.0
        let estimatedTokensLimit = Int64(limitUSD * 100_000)

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        let projectedCost = currentCost * Decimal(Double(daysInMonth) / Double(max(currentDay, 1)))

        return UsageData(
            tokensUsed: estimatedTokensUsed,
            tokensLimit: estimatedTokensLimit,
            inputTokens: nil,
            outputTokens: nil,
            periodStart: startOfMonth,
            periodEnd: endOfMonth,
            resetDate: endOfMonth,
            currentCost: currentCost,
            projectedCost: projectedCost,
            currency: "USD",
            tier: subscription.plan?.title ?? "Pay as you go",
            lastUpdated: now,
            fiveHourUsage: nil,
            sevenDayUsage: nil
        )
    }
}
