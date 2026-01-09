import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var selectedService: ServiceViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L.aiUsage)
                    .font(.headline)

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            VStack(spacing: 16) {
                // Circular Gauges
                HStack(spacing: 36) {
                    ForEach(enabledServices) { service in
                        CircularGaugeView(service: service)
                    }
                }
                .padding(.top, 8)

                // Detail Cards
                VStack(spacing: 8) {
                    ForEach(enabledServices) { service in
                        DetailCard(service: service)
                    }
                }

                // Usage History Section
                if !enabledServices.isEmpty {
                    CombinedUsageHistoryView(serviceTypes: enabledServices.map { $0.config.serviceType })
                        .frame(height: 120)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Footer
            HStack {
                if appState.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L.updating)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else if let lastRefresh = appState.lastRefreshDate {
                    Text("\(L.lastUpdate): \(lastRefresh, style: .relative) \(L.ago)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    Task { await appState.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(appState.isRefreshing)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    private var enabledServices: [ServiceViewModel] {
        appState.services.filter { $0.config.isEnabled }
    }
}

// MARK: - Circular Gauge (Dual Ring)

struct CircularGaugeView: View {
    let service: ServiceViewModel

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer ring background (5h)
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    .frame(width: 72, height: 72)

                // Outer ring - 5h remaining
                Circle()
                    .trim(from: 0, to: CGFloat(fiveHourRemaining))
                    .stroke(service.brandColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                // Inner ring background (7d)
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 4)
                    .frame(width: 54, height: 54)

                // Inner ring - 7d remaining
                Circle()
                    .trim(from: 0, to: CGFloat(sevenDayRemaining))
                    .stroke(service.brandColor.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: -2) {
                    Text("\(Int(fiveHourRemaining * 100))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("\(Int(sevenDayRemaining * 100))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Text(service.name)
                .font(.system(size: 13, weight: .medium))
        }
    }

    private var fiveHourRemaining: Double {
        let usage = service.fiveHourUsage ?? service.usagePercentage
        return max(0, (100.0 - usage)) / 100.0
    }

    private var sevenDayRemaining: Double {
        let usage = service.sevenDayUsage ?? 0
        return max(0, (100.0 - usage)) / 100.0
    }
}

// MARK: - Detail Card

struct DetailCard: View {
    let service: ServiceViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Header: Name + Plan badge
            HStack(alignment: .center) {
                Circle()
                    .fill(service.brandColor)
                    .frame(width: 10, height: 10)

                Text(service.name)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                // Plan badge
                Text(formattedPlan)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(service.brandColor.opacity(0.15))
                    .foregroundStyle(service.brandColor)
                    .clipShape(Capsule())
            }

            // Remaining quota bars
            HStack(spacing: 16) {
                // 5-hour remaining
                UsageBar(
                    label: "5h",
                    percentage: max(0, 100 - (service.fiveHourUsage ?? service.usagePercentage)),
                    resetText: formatReset(service.resetDate),
                    color: service.brandColor
                )

                // 7-day remaining
                if let sevenDay = service.sevenDayUsage {
                    UsageBar(
                        label: "7d",
                        percentage: max(0, 100 - sevenDay),
                        resetText: formatSevenDayReset(service.sevenDayResetDate),
                        color: service.brandColor.opacity(0.6)
                    )
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var formattedPlan: String {
        let tier = service.tier.lowercased()
        if tier.contains("max") {
            return "Max"
        } else if tier.contains("pro") {
            return "Pro"
        } else if tier.contains("team") {
            return "Team"
        } else if tier.contains("enterprise") {
            return "Enterprise"
        } else if tier.contains("free") {
            return "Free"
        }
        return service.tier.components(separatedBy: "_").last?.capitalized ?? service.tier
    }

    private func formatReset(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        let timeText = L.formatHoursMinutes(hours, minutes)
        return L.formatResetTime(timeText)
    }

    private func formatSevenDayReset(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)

        let timeText = L.formatDaysHours(days, hours)
        return L.formatResetTime(timeText)
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let label: String
    let percentage: Double
    let resetText: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 7)
                }
            }
            .frame(height: 7)

            // Next refill time
            if let reset = resetText {
                Text(reset)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
