import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appState: AppState

    @State private var claudeApiKey: String = ""
    @State private var openAIApiKey: String = ""
    @State private var geminiApiKey: String = ""

    @State private var claudeEnabled: Bool = true
    @State private var openAIEnabled: Bool = true
    @State private var geminiEnabled: Bool = true

    @State private var refreshInterval: TimeInterval = 300
    @State private var notificationsEnabled: Bool = false
    @State private var notificationThreshold: Double = 80

    @State private var showingSaveConfirmation: Bool = false
    @State private var saveError: String?

    private let keychain = KeychainManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Service Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API Keys")
                            .font(.headline)
                            .padding(.horizontal)

                        ServiceSettingsRow(
                            service: .claude,
                            apiKey: $claudeApiKey,
                            isEnabled: $claudeEnabled
                        )
                        .padding(.horizontal)

                        ServiceSettingsRow(
                            service: .openai,
                            apiKey: $openAIApiKey,
                            isEnabled: $openAIEnabled
                        )
                        .padding(.horizontal)

                        ServiceSettingsRow(
                            service: .gemini,
                            apiKey: $geminiApiKey,
                            isEnabled: $geminiEnabled
                        )
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // General Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("General")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Refresh Interval")
                                .font(.subheadline)

                            Picker("", selection: $refreshInterval) {
                                Text("1 minute").tag(TimeInterval(60))
                                Text("5 minutes").tag(TimeInterval(300))
                                Text("15 minutes").tag(TimeInterval(900))
                                Text("30 minutes").tag(TimeInterval(1800))
                                Text("1 hour").tag(TimeInterval(3600))
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)

                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $notificationsEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Enable Notifications")
                                        .font(.subheadline)
                                    Text("Get notified when usage exceeds threshold")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if notificationsEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Notification Threshold")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(notificationThreshold))%")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }

                                    Slider(value: $notificationThreshold, in: 50...95, step: 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }

            Divider()

            // Footer
            HStack {
                if let error = saveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if showingSaveConfirmation {
                    Label("Settings saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        claudeApiKey = (try? keychain.retrieve(for: "claude_api_key")) ?? ""
        openAIApiKey = (try? keychain.retrieve(for: "openai_api_key")) ?? ""
        geminiApiKey = (try? keychain.retrieve(for: "gemini_api_key")) ?? ""

        if let claudeService = appState.services.first(where: { $0.config.serviceType == .claude }) {
            claudeEnabled = claudeService.config.isEnabled
            refreshInterval = claudeService.config.refreshInterval
            notificationThreshold = claudeService.config.notificationThreshold
        }
    }

    private func saveSettings() {
        saveError = nil
        showingSaveConfirmation = false

        do {
            if !claudeApiKey.isEmpty {
                try keychain.save(claudeApiKey, for: "claude_api_key")
            }
            if !openAIApiKey.isEmpty {
                try keychain.save(openAIApiKey, for: "openai_api_key")
            }
            if !geminiApiKey.isEmpty {
                try keychain.save(geminiApiKey, for: "gemini_api_key")
            }

            for i in appState.services.indices {
                switch appState.services[i].config.serviceType {
                case .claude:
                    appState.services[i].config.apiKey = claudeApiKey
                    appState.services[i].config.isEnabled = claudeEnabled
                case .openai:
                    appState.services[i].config.apiKey = openAIApiKey
                    appState.services[i].config.isEnabled = openAIEnabled
                case .gemini:
                    appState.services[i].config.apiKey = geminiApiKey
                    appState.services[i].config.isEnabled = geminiEnabled
                }

                appState.services[i].config.refreshInterval = refreshInterval
                appState.services[i].config.notificationThreshold = notificationThreshold
            }

            showingSaveConfirmation = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }

        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
        }
    }
}
