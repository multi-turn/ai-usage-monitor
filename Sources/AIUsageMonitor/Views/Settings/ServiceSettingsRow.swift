import SwiftUI

struct ServiceSettingsRow: View {
    let service: ServiceType
    @Binding var apiKey: String
    @Binding var isEnabled: Bool
    @State private var connectionStatus: ConnectionStatus = .disconnected

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: service.iconName)
                    .font(.title2)
                    .foregroundStyle(Color(hex: service.brandColorHex) ?? .blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.displayName)
                        .font(.headline)

                    StatusIndicatorView(status: connectionStatus)
                }

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }

            if isEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("Enter API key...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            updateConnectionStatus()
                        }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            updateConnectionStatus()
        }
    }

    private func updateConnectionStatus() {
        if apiKey.isEmpty {
            connectionStatus = .disconnected
        } else if apiKey.count < 10 {
            connectionStatus = .error
        } else {
            connectionStatus = .connected
        }
    }
}
