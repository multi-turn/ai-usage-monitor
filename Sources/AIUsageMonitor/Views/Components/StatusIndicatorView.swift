import SwiftUI

struct StatusIndicatorView: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(status.displayText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

enum ConnectionStatus {
    case connected
    case disconnected
    case checking
    case error

    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .gray
        case .checking: return .orange
        case .error: return .red
        }
    }

    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Not configured"
        case .checking: return "Checking..."
        case .error: return "Error"
        }
    }
}
