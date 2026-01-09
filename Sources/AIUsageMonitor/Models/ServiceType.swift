import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case codex = "Codex"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .codex: return "terminal"
        }
    }

    var brandColorHex: String {
        switch self {
        case .claude: return "#D97706"  // Orange
        case .codex: return "#10A37F"   // Teal Green
        }
    }
}
