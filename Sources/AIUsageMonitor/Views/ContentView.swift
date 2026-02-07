import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var showSettings: Bool = false
    @State private var lastDisappearTime: Date?

    private let autoResetDelay: TimeInterval = 10

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 0) {
                if showSettings {
                    SettingsPanel(appState: appState, showSettings: $showSettings)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    MainPanel(appState: appState, showSettings: $showSettings)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showSettings)
        }
        .frame(width: 300)
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




struct PulsingLoadingIndicator: View {
    @State private var phase: CGFloat = 0
    @State private var glowOpacity: Double = 0.4

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .blur(radius: 6 + phase * 4)
                    .opacity(glowOpacity)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.9))
                    .frame(width: 10, height: 10)
                    .shadow(color: .white.opacity(0.6), radius: 4 + phase * 6)
            }
            .frame(width: 24, height: 24)

            Text(L.updating)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                phase = 1
                glowOpacity = 0.9
            }
        }
    }
}

struct SpinningRefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(rotation))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(isRefreshing)
        .onChange(of: isRefreshing) { _, refreshing in
            if refreshing {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rotation = 0
                }
            }
        }
    }
}

struct StaggerAppear: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.8).delay(delay),
                value: appeared
            )
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.15 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

struct MainPanel: View {
    @Bindable var appState: AppState
    @Binding var showSettings: Bool

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L.aiUsage)
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 14) {
                HStack(spacing: enabledServices.count >= 3 ? 20 : 32) {
                    ForEach(Array(enabledServices.enumerated()), id: \.element.id) { index, service in
                        CircularGaugeView(service: service, compact: enabledServices.count >= 3)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.08),
                                value: appeared
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                VStack(spacing: 10) {
                    ForEach(Array(enabledServices.enumerated()), id: \.element.id) { index, service in
                        DetailCard(service: service, onRefresh: { Task { await appState.refresh() } })
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(0.15 + Double(index) * 0.08),
                                value: appeared
                            )
                    }
                }

                if !enabledServices.isEmpty {
                    CombinedUsageHistoryView(serviceTypes: enabledServices.map { $0.config.serviceType })
                        .frame(height: 120)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.75).delay(0.3),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.3).padding(.horizontal, 16)

            HStack {
                if appState.isRefreshing {
                    PulsingLoadingIndicator()
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else if let lastRefresh = appState.lastRefreshDate {
                    Text(formatLastUpdate(lastRefresh))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                        .transition(.opacity)
                }

                Spacer()

                SpinningRefreshButton(isRefreshing: appState.isRefreshing) {
                    Task { await appState.refresh() }
                }

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .opacity(0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.easeInOut(duration: 0.3), value: appState.isRefreshing)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
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

struct SettingsPanel: View {
    @Bindable var appState: AppState
    @Binding var showSettings: Bool

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showSettings = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()

                Text(L.settings)
                    .font(.system(size: 16, weight: .bold))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.services)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ServiceToggle(name: "Claude", color: ServiceType.claude.brandColor, isOn: claudeEnabledBinding)
                            .modifier(StaggerAppear(appeared: appeared, delay: 0.0))
                        ServiceToggle(name: "Codex", color: ServiceType.codex.brandColor, isOn: codexEnabledBinding)
                            .modifier(StaggerAppear(appeared: appeared, delay: 0.04))
                        ServiceToggle(name: "Gemini", color: ServiceType.gemini.brandColor, isOn: geminiEnabledBinding)
                            .modifier(StaggerAppear(appeared: appeared, delay: 0.08))
                    }
                    .padding(.horizontal, 16)

                    Divider().opacity(0.3).padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.general)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack {
                            Text(L.launchAtLogin)
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { appState.setLaunchAtLogin($0) }
                            ))
                            .toggleStyle(.switch)
                            .tint(.blue)
                            .labelsHidden()
                            .scaleEffect(0.75)
                            .frame(width: 38, height: 22)
                        }

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



                    }
                    .padding(.horizontal, 16)
                    .modifier(StaggerAppear(appeared: appeared, delay: 0.1))

                    Divider().opacity(0.3).padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L.language)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.roundedRectangle(radius: 10))
                    }
                    .padding(.horizontal, 16)
                    .modifier(StaggerAppear(appeared: appeared, delay: 0.15))
                }
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
        .onDisappear { appeared = false }
    }

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

struct CircularGaugeView: View {
    let service: ServiceViewModel
    var compact: Bool = false

    @State private var animatedFiveHour: Double = 0
    @State private var animatedSevenDay: Double = 0
    @State private var appeared = false
    @State private var pulseScale: CGFloat = 1.0

    private var outerSize: CGFloat { compact ? 68 : 82 }
    private var innerSize: CGFloat { compact ? 52 : 64 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [service.brandColor.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: outerSize / 2
                        )
                    )
                    .frame(width: outerSize + 12, height: outerSize + 12)
                    .scaleEffect(pulseScale)

                Circle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 5.5)
                    .frame(width: outerSize, height: outerSize)

                Circle()
                    .trim(from: 0, to: CGFloat(animatedFiveHour))
                    .stroke(
                        AngularGradient(
                            colors: [service.brandColor.opacity(0.4), service.brandColor],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * animatedFiveHour)
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: outerSize, height: outerSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: service.brandColor.opacity(0.3), radius: 4)

                Circle()
                    .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 4)
                    .frame(width: innerSize, height: innerSize)

                Circle()
                    .trim(from: 0, to: CGFloat(animatedSevenDay))
                    .stroke(
                        service.brandColor.opacity(0.5),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .frame(width: innerSize, height: innerSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: service.brandColor.opacity(0.2), radius: 3)

                if service.isAuthError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                        .modifier(PulseEffect())
                } else {
                    VStack(spacing: compact ? -2 : -1) {
                        Text("\(Int(animatedFiveHour * 100))")
                            .font(.system(size: compact ? 20 : 24, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("\(Int(animatedSevenDay * 100))")
                            .font(.system(size: compact ? 12 : 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1 : 0)

            Text(service.name)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(service.isAuthError ? .secondary : .primary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                appeared = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                animatedFiveHour = fiveHourRemaining
                animatedSevenDay = sevenDayRemaining
            }
        }
        .onChange(of: fiveHourRemaining) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                animatedFiveHour = newValue
            }
            triggerPulse()
        }
        .onChange(of: sevenDayRemaining) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                animatedSevenDay = newValue
            }
        }
    }

    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.15)) { pulseScale = 1.08 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) { pulseScale = 1.0 }
    }

    private var fiveHourRemaining: Double {
        if service.isAuthError { return 0 }
        let usage = service.fiveHourUsage ?? service.usagePercentage
        return max(0, (100.0 - usage)) / 100.0
    }

    private var sevenDayRemaining: Double {
        if service.isAuthError { return 0 }
        let usage = service.sevenDayUsage ?? 0
        return max(0, (100.0 - usage)) / 100.0
    }
}

struct DetailCard: View {
    let service: ServiceViewModel
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                Circle()
                    .fill(service.isAuthError ? ThemeManager.shared.current.statusDanger : service.brandColor)
                    .frame(width: 8, height: 8)

                Text(service.name)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if service.isAuthError {
                    Text("재인증 필요")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.current.statusDanger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(ThemeManager.shared.current.statusDanger.opacity(0.25)), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(formattedPlan)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(service.brandColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(service.brandColor.opacity(0.25)), in: .capsule)
                }
            }

            if service.isAuthError {
                AuthErrorView(service: service, onRefresh: onRefresh)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: 16) {
                    UsageBar(
                        label: primaryLabel,
                        percentage: max(0, 100 - (service.fiveHourUsage ?? service.usagePercentage)),
                        resetText: primaryResetText,
                        color: service.brandColor
                    )

                    if let sevenDay = service.sevenDayUsage {
                        UsageBar(
                            label: secondaryLabel,
                            percentage: max(0, 100 - sevenDay),
                            resetText: formatReset(service.sevenDayResetDate),
                            color: service.brandColor.opacity(0.5)
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(12)
        .premiumCard()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: service.isAuthError)
    }

    private var isGemini: Bool {
        service.config.serviceType == .gemini
    }

    private var primaryLabel: String {
        isGemini ? "Pro" : "5h"
    }

    private var secondaryLabel: String {
        isGemini ? "Flash" : "7d"
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

    private var primaryResetText: String? {
        let usage = service.fiveHourUsage ?? service.usagePercentage
        if usage < 1 && !isGemini {
            return L.resetOnUse
        }
        return formatReset(service.resetDate)
    }

    private func formatReset(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let totalMinutes = Int(interval / 60)
        if totalMinutes < 60 {
            return L.formatResetTime(L.formatMinutes(totalMinutes))
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours < 24 {
            let timeText = L.formatHoursMinutes(hours, minutes)
            return L.formatResetTime(timeText)
        }

        let days = Int(interval / 86400)
        let remainingHours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let timeText = L.formatDaysHours(days, remainingHours)
        return L.formatResetTime(timeText)
    }
}

struct AuthErrorView: View {
    let service: ServiceViewModel
    var onRefresh: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 14))
                    .modifier(PulseEffect())

                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: openTerminalWithCommand) {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                        Text(buttonLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)

                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var needsLogout: Bool {
        guard let error = service.lastError?.lowercased() else { return false }
        return error.contains("scope") || error.contains("permission") || error.contains("403")
            || error.contains("/logout")
    }

    private var errorMessage: String {
        if let error = service.lastError {
            let lower = error.lowercased()
            if lower.contains("scope") || lower.contains("permission") {
                return "토큰 권한이 부족합니다. 로그아웃 후 재로그인해주세요."
            }
            if lower.contains("만료") || lower.contains("expired") || lower.contains("revoke") {
                return "토큰이 만료되었습니다. 재로그인해주세요."
            }
        }
        switch service.config.serviceType {
        case .claude: return "Claude 인증이 필요합니다."
        case .gemini: return "Gemini 인증이 필요합니다."
        case .codex: return "Codex 인증이 필요합니다."
        }
    }

    private var buttonLabel: String {
        switch service.config.serviceType {
        case .claude: return needsLogout ? "로그아웃 후 재로그인" : "claude 실행하기"
        case .gemini: return "gemini auth 실행하기"
        case .codex: return "codex 실행하기"
        }
    }

    private func openTerminalWithCommand() {
        let command: String
        switch service.config.serviceType {
        case .claude:
            command = needsLogout ? "claude /logout && claude" : "claude"
        case .gemini:
            command = "gemini"
        case .codex:
            command = "codex"
        }

        let scriptPath = NSTemporaryDirectory() + "aimonitor-reauth.command"
        let scriptContent = "#!/bin/bash\necho '🔄 재인증 중...'\n\(command)\necho ''\necho '✅ 완료! 이 창을 닫아도 됩니다.'\nread -p ''\n"
        try? scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        NSWorkspace.shared.open(URL(fileURLWithPath: scriptPath))
    }
}

struct UsageBar: View {
    let label: String
    let percentage: Double
    let resetText: String?
    let color: Color

    @State private var animatedPercentage: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(Int(animatedPercentage))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                let barWidth = geo.size.width * CGFloat(animatedPercentage) / 100
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(Color(nsColor: .separatorColor).opacity(0.2))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.75), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth, height: 7)
                        .shadow(color: color.opacity(0.25), radius: 3, y: 1)
                }
            }
            .frame(height: 7)

            if let reset = resetText {
                Text(reset)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedPercentage = percentage
            }
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack {
                Text("v\(currentVersion)")
                    .font(.subheadline)

                Spacer()

                Button {
                    Updater.shared.checkForUpdates()
                } label: {
                    Text(L.checkUpdate)
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal, 16)
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

struct ServiceToggle: View {
    let name: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(color)
                .labelsHidden()
                .scaleEffect(0.75)
                .frame(width: 38, height: 22)
        }
    }
}


