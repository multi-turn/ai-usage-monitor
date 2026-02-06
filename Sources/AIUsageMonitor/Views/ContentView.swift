import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var showSettings: Bool = false
    @State private var lastDisappearTime: Date?
    
    private let autoResetDelay: TimeInterval = 10

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsPanel(appState: appState, showSettings: $showSettings)
            } else {
                MainPanel(appState: appState, showSettings: $showSettings)
            }
        }
        .frame(width: 300)
        .background(ThemeManager.shared.current.background)
        .preferredColorScheme(ThemeManager.shared.effectiveMode == .dark ? .dark : .light)
        .animation(nil, value: showSettings)
        .onAppear {
            if showSettings,
               let lastDisappear = lastDisappearTime,
               Date().timeIntervalSince(lastDisappear) >= autoResetDelay {
                showSettings = false
            }
        }
        .onDisappear {
            lastDisappearTime = Date()
        }
    }
}

// MARK: - Main Panel

struct MainPanel: View {
    @Bindable var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L.aiUsage)
                    .font(.headline)

                Spacer()

                Button {
                    showSettings = true
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
                    Text(formatLastUpdate(lastRefresh))
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
    }

    private var enabledServices: [ServiceViewModel] {
        appState.services.filter { $0.config.isEnabled }
    }

    private func formatLastUpdate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60

        let timeText: String
        if hours > 0 {
            timeText = "\(hours)h \(minutes % 60)m"
        } else if minutes > 0 {
            timeText = "\(minutes)m \(seconds % 60)s"
        } else {
            timeText = "\(seconds)s"
        }

        return "\(L.lastUpdate): \(timeText) \(L.ago)"
    }
}

// MARK: - Settings Panel (Inline)

struct SettingsPanel: View {
    @Bindable var appState: AppState
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    showSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(L.settings)
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 16) {
                    // Services Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.services)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        // Claude
                        Toggle(isOn: claudeEnabledBinding) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "#D97706") ?? .orange)
                                    .frame(width: 10, height: 10)
                                Text("Claude")
                                    .font(.subheadline)
                            }
                        }
                        .toggleStyle(BrandedCheckboxToggleStyle(tint: Color(hex: "#D97706") ?? .orange))

                        // Codex
                        Toggle(isOn: codexEnabledBinding) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "#10A37F") ?? .green)
                                    .frame(width: 10, height: 10)
                                Text("Codex")
                                    .font(.subheadline)
                            }
                        }
                        .toggleStyle(BrandedCheckboxToggleStyle(tint: Color(hex: "#10A37F") ?? .green))

                        Toggle(isOn: geminiEnabledBinding) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "#4285F4") ?? .blue)
                                    .frame(width: 10, height: 10)
                                Text("Gemini")
                                    .font(.subheadline)
                            }
                        }
                        .toggleStyle(BrandedCheckboxToggleStyle(tint: Color(hex: "#4285F4") ?? .blue))
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // General Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.general)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Toggle(isOn: Binding(
                            get: { appState.launchAtLogin },
                            set: { appState.setLaunchAtLogin($0) }
                        )) {
                            Text(L.launchAtLogin)
                                .font(.subheadline)
                        }
                        .toggleStyle(BrandedCheckboxToggleStyle(tint: .blue))

                        // Refresh Interval
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.refreshInterval)
                                .font(.subheadline)

                            Picker("", selection: refreshIntervalBinding) {
                                Text("1m").tag(TimeInterval(60))
                                Text("5m").tag(TimeInterval(300))
                                Text("15m").tag(TimeInterval(900))
                                Text("30m").tag(TimeInterval(1800))
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(L.theme)
                                .font(.subheadline)

                            Picker("", selection: Binding(
                                get: { ThemeManager.shared.mode },
                                set: { ThemeManager.shared.mode = $0 }
                            )) {
                                ForEach(ThemeMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Language Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.language)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(Language.allCases, id: \.self) { lang in
                                Button {
                                    L.currentLanguage = lang
                                } label: {
                                    if L.currentLanguage == lang {
                                        Label(lang.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(lang.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(L.currentLanguage.displayName)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)


                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Auto-apply Bindings

    private var claudeEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.services.first { $0.config.serviceType == .claude }?.config.isEnabled ?? true },
            set: { newValue in
                if let idx = appState.services.firstIndex(where: { $0.config.serviceType == .claude }) {
                    appState.services[idx].config.isEnabled = newValue
                }
            }
        )
    }

    private var codexEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.services.first { $0.config.serviceType == .codex }?.config.isEnabled ?? true },
            set: { newValue in
                if let idx = appState.services.firstIndex(where: { $0.config.serviceType == .codex }) {
                    appState.services[idx].config.isEnabled = newValue
                }
            }
        )
    }

    private var geminiEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.services.first { $0.config.serviceType == .gemini }?.config.isEnabled ?? true },
            set: { newValue in
                if let idx = appState.services.firstIndex(where: { $0.config.serviceType == .gemini }) {
                    appState.services[idx].config.isEnabled = newValue
                }
            }
        )
    }

    private var refreshIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { appState.services.first?.config.refreshInterval ?? 300 },
            set: { newValue in
                for i in appState.services.indices {
                    appState.services[i].config.refreshInterval = newValue
                }
                appState.updateRefreshInterval(newValue)
            }
        )
    }

}

// MARK: - Circular Gauge (Dual Ring)

struct CircularGaugeView: View {
    let service: ServiceViewModel
    
    @State private var animatedFiveHour: Double = 0
    @State private var animatedSevenDay: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer ring background (5h)
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    .frame(width: 72, height: 72)

                // Outer ring - 5h remaining
                Circle()
                    .trim(from: 0, to: CGFloat(animatedFiveHour))
                    .stroke(service.brandColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                // Inner ring background (7d)
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 4)
                    .frame(width: 54, height: 54)

                // Inner ring - 7d remaining
                Circle()
                    .trim(from: 0, to: CGFloat(animatedSevenDay))
                    .stroke(service.brandColor.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: -2) {
                    Text("\(Int(animatedFiveHour * 100))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("\(Int(animatedSevenDay * 100))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            Text(service.name)
                .font(.system(size: 13, weight: .medium))
        }
        .onAppear {
            animatedFiveHour = fiveHourRemaining
            animatedSevenDay = sevenDayRemaining
        }
        .onChange(of: fiveHourRemaining) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedFiveHour = newValue
            }
        }
        .onChange(of: sevenDayRemaining) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedSevenDay = newValue
            }
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
                    resetText: fiveHourResetText,
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ThemeManager.shared.current.border, lineWidth: 0.5)
        )
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

    private var fiveHourResetText: String? {
        let usage = service.fiveHourUsage ?? service.usagePercentage
        if usage < 1 {
            return L.resetOnUse
        }
        return formatReset(service.resetDate)
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
    
    @State private var animatedPercentage: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(animatedPercentage))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(animatedPercentage) / 100, height: 7)
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
        .onAppear {
            animatedPercentage = percentage
        }
        .onChange(of: percentage) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedPercentage = newValue
            }
        }
    }
}

struct UpdateSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.update)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack {
                Text("v\(currentVersion)")
                    .font(.subheadline)

                Spacer()

                Button {
                    Updater.shared.checkForUpdates()
                } label: {
                    Text(L.checkUpdate)
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

struct BrandedCheckboxToggleStyle: ToggleStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack {
                configuration.label
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(configuration.isOn ? tint : Color.primary.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(configuration.isOn ? 0.0 : 0.18), lineWidth: 1)
                        }
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(configuration.isOn ? 1 : 0)
                        .scaleEffect(configuration.isOn ? 1 : 0.6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
