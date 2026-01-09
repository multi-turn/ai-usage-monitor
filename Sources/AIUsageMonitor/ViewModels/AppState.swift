import Foundation
import SwiftUI
import Combine
import ServiceManagement

@Observable
class AppState {
    var services: [ServiceViewModel] = []
    var isRefreshing: Bool = false
    var lastRefreshDate: Date?
    var errorMessage: String?
    var showingSettings: Bool = false
    var launchAtLogin: Bool = false

    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 300 // 5 minutes default

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
        loadLaunchAtLoginState()
        // Auto-refresh on launch
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            await refresh()
            await MainActor.run {
                startAutoRefreshTimer()
            }
        }
    }

    deinit {
        stopAutoRefreshTimer()
    }

    // MARK: - Auto Refresh Timer

    func startAutoRefreshTimer() {
        stopAutoRefreshTimer()

        // Get refresh interval from first enabled service
        if let enabledService = services.first(where: { $0.config.isEnabled }) {
            refreshInterval = enabledService.config.refreshInterval
        }

        print("⏰ Starting auto-refresh timer: \(Int(refreshInterval))s interval")

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopAutoRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func updateRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        startAutoRefreshTimer()
    }

    // MARK: - Launch at Login

    func loadLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ Launch at login disabled")
                }
                launchAtLogin = enabled
            } catch {
                print("❌ Failed to set launch at login: \(error)")
            }
        }
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
        print("🔄 Starting refresh...")
        isRefreshing = true
        defer { isRefreshing = false }

        let results = await withTaskGroup(of: (Int, String, Result<UsageData, Error>).self) { group in
            for (index, service) in services.enumerated() {
                guard service.config.isEnabled else {
                    print("⏭️ Skipping disabled service: \(service.name)")
                    continue
                }
                let serviceName = service.name
                print("📡 Fetching: \(serviceName)")

                group.addTask {
                    do {
                        let client = self.createAPIClient(for: service.config)
                        let usage = try await client.fetchUsage()
                        print("✅ \(serviceName): \(usage.usagePercentage)%")
                        return (index, serviceName, .success(usage))
                    } catch {
                        print("❌ \(serviceName) error: \(error)")
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
                    print("📊 Updated \(serviceName): \(usage.usagePercentage)%")

                    // Save to history
                    let historyEntry = UsageHistoryEntry(
                        serviceType: services[index].config.serviceType,
                        fiveHourUsage: usage.fiveHourUsage,
                        sevenDayUsage: usage.sevenDayUsage
                    )
                    UsageHistoryStore.shared.saveEntry(historyEntry)

                case .failure(let error):
                    errors.append("\(serviceName): \(error.localizedDescription)")
                }
            }
            lastRefreshDate = Date()
            errorMessage = errors.isEmpty ? nil : errors.joined(separator: "; ")
            print("🏁 Refresh complete. Errors: \(errorMessage ?? "none")")
        }
    }

    private func createAPIClient(for config: ServiceConfig) -> AIServiceAPI {
        switch config.serviceType {
        case .claude:
            return AnthropicClient(config: config)
        case .codex:
            return CodexClient(config: config)
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
    var sevenDayResetDate: Date? { usage.sevenDayResetDate }
    var daysUntilSevenDayReset: Int? { usage.daysUntilSevenDayReset }

    // Claude-specific
    var fiveHourUsage: Double? { usage.fiveHourUsage }
    var sevenDayUsage: Double? { usage.sevenDayUsage }
    var hasClaudeUsageWindows: Bool { fiveHourUsage != nil || sevenDayUsage != nil }

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
