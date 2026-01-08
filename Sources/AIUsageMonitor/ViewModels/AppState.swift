import Foundation
import SwiftUI

@Observable
class AppState {
    var services: [ServiceViewModel] = []
    var isRefreshing: Bool = false
    var lastRefreshDate: Date?
    var errorMessage: String?
    var showingSettings: Bool = false

    var totalUsagePercentage: Double {
        guard !services.isEmpty else { return 0 }
        return services.map(\.usagePercentage).reduce(0, +) / Double(services.count)
    }

    var iconName: String {
        switch totalUsagePercentage {
        case 0..<25:
            return "chart.bar.fill"
        case 25..<50:
            return "chart.bar.fill"
        case 50..<75:
            return "exclamationmark.circle.fill"
        case 75...100:
            return "exclamationmark.triangle.fill"
        default:
            return "chart.bar"
        }
    }

    init() {
        setupPlaceholderServices()
    }

    private func setupPlaceholderServices() {
        services = ServiceType.allCases.map { type in
            ServiceViewModel(
                config: ServiceConfig(serviceType: type),
                usage: UsageData.placeholder(for: type)
            )
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let results = await withTaskGroup(of: (Int, String, Result<UsageData, Error>).self) { group in
            for (index, service) in services.enumerated() {
                guard service.config.isEnabled else { continue }
                let serviceName = service.name

                group.addTask {
                    do {
                        let client = self.createAPIClient(for: service.config)
                        let usage = try await client.fetchUsage()
                        return (index, serviceName, .success(usage))
                    } catch {
                        return (index, serviceName, .failure(error))
                    }
                }
            }

            var collected: [(Int, String, Result<UsageData, Error>)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        await MainActor.run {
            var errors: [String] = []
            for (index, serviceName, result) in results {
                switch result {
                case .success(let usage):
                    services[index].usage = usage
                case .failure(let error):
                    errors.append("\(serviceName): \(error.localizedDescription)")
                }
            }
            lastRefreshDate = Date()
            errorMessage = errors.isEmpty ? nil : errors.joined(separator: "; ")
        }
    }

    private func createAPIClient(for config: ServiceConfig) -> AIServiceAPI {
        switch config.serviceType {
        case .openai:
            return OpenAIClient(config: config)
        case .claude:
            return AnthropicClient(config: config)
        case .gemini:
            return GeminiClient(config: config)
        }
    }
}

@Observable
class ServiceViewModel: Identifiable {
    let id: UUID
    var config: ServiceConfig
    var usage: UsageData

    init(config: ServiceConfig, usage: UsageData) {
        self.id = config.id
        self.config = config
        self.usage = usage
    }

    var name: String { config.displayName }
    var iconName: String { config.iconName }
    var brandColor: Color { config.brandColor }
    var tier: String { usage.tier }
    var tokensUsed: Int64 { usage.tokensUsed }
    var tokensLimit: Int64 { usage.tokensLimit }
    var usagePercentage: Double { usage.usagePercentage }
    var currentCost: Decimal? { usage.currentCost }
    var projectedCost: Decimal? { usage.projectedCost }
    var currency: String { usage.currency }
    var resetDate: Date? { usage.resetDate }

    var formattedTokensUsed: String { formatTokens(tokensUsed) }
    var formattedTokensLimit: String { formatTokens(tokensLimit) }

    var status: ServiceStatus {
        switch usagePercentage {
        case 0..<75: return .normal
        case 75..<90: return .warning
        default: return .critical
        }
    }

    private func formatTokens(_ tokens: Int64) -> String {
        let value = Double(tokens)
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return "\(Int(value))"
        }
    }
}

enum ServiceStatus {
    case normal, warning, critical

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
