import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var appState: AppState

    @State private var claudeEnabled: Bool = true
    @State private var codexEnabled: Bool = true
    @State private var refreshInterval: TimeInterval = 300
    @State private var selectedLanguage: Language = L.currentLanguage

    @State private var showingSaveConfirmation: Bool = false
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L.settings)
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
                    // Language Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.language)
                            .font(.headline)
                            .padding(.horizontal)

                        Picker("", selection: $selectedLanguage) {
                            ForEach(Language.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Service Toggle Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L.services)
                            .font(.headline)
                            .padding(.horizontal)

                        // Claude
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#D97706") ?? .orange)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Claude")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Claude Code OAuth")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $claudeEnabled)
                                .labelsHidden()
                        }
                        .padding(.horizontal)

                        // Codex
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#10A37F") ?? .green)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Codex")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("~/.codex sessions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $codexEnabled)
                                .labelsHidden()
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // General Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L.general)
                            .font(.headline)
                            .padding(.horizontal)

                        // Launch at Login
                        HStack {
                            Text(L.launchAtLogin)
                                .font(.subheadline)

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { appState.launchAtLogin },
                                set: { appState.setLaunchAtLogin($0) }
                            ))
                            .labelsHidden()
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.refreshInterval)
                                .font(.subheadline)

                            Picker("", selection: $refreshInterval) {
                                Text("1 \(L.minutes)").tag(TimeInterval(60))
                                Text("5 \(L.minutes)").tag(TimeInterval(300))
                                Text("15 \(L.minutes)").tag(TimeInterval(900))
                                Text("30 \(L.minutes)").tag(TimeInterval(1800))
                            }
                            .pickerStyle(.segmented)
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
                    Label(savedText, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Button(cancelText) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(saveText) {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 360, height: 500)
        .onAppear {
            loadSettings()
        }
    }

    private var cancelText: String {
        switch L.currentLanguage {
        case .english: return "Cancel"
        case .korean: return "취소"
        case .japanese: return "キャンセル"
        case .chinese: return "取消"
        case .spanish: return "Cancelar"
        case .french: return "Annuler"
        case .german: return "Abbrechen"
        case .portuguese: return "Cancelar"
        case .russian: return "Отмена"
        case .italian: return "Annulla"
        }
    }

    private var saveText: String {
        switch L.currentLanguage {
        case .english: return "Save"
        case .korean: return "저장"
        case .japanese: return "保存"
        case .chinese: return "保存"
        case .spanish: return "Guardar"
        case .french: return "Enregistrer"
        case .german: return "Speichern"
        case .portuguese: return "Salvar"
        case .russian: return "Сохранить"
        case .italian: return "Salva"
        }
    }

    private var savedText: String {
        switch L.currentLanguage {
        case .english: return "Saved"
        case .korean: return "저장됨"
        case .japanese: return "保存済み"
        case .chinese: return "已保存"
        case .spanish: return "Guardado"
        case .french: return "Enregistré"
        case .german: return "Gespeichert"
        case .portuguese: return "Salvo"
        case .russian: return "Сохранено"
        case .italian: return "Salvato"
        }
    }

    private func loadSettings() {
        if let claudeService = appState.services.first(where: { $0.config.serviceType == .claude }) {
            claudeEnabled = claudeService.config.isEnabled
            refreshInterval = claudeService.config.refreshInterval
        }

        if let codexService = appState.services.first(where: { $0.config.serviceType == .codex }) {
            codexEnabled = codexService.config.isEnabled
        }

        selectedLanguage = L.currentLanguage
    }

    private func saveSettings() {
        saveError = nil
        showingSaveConfirmation = false

        // Save language
        L.currentLanguage = selectedLanguage

        for i in appState.services.indices {
            switch appState.services[i].config.serviceType {
            case .claude:
                appState.services[i].config.isEnabled = claudeEnabled
            case .codex:
                appState.services[i].config.isEnabled = codexEnabled
            }

            appState.services[i].config.refreshInterval = refreshInterval
        }

        // Update the auto-refresh timer with new interval
        appState.updateRefreshInterval(refreshInterval)

        showingSaveConfirmation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}
