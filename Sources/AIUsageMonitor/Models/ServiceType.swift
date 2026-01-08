import Foundation

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "ChatGPT (OpenAI)"
        case .gemini: return "Gemini (Google)"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .openai: return "sparkles"
        case .gemini: return "diamond"
        }
    }

    var brandColorHex: String {
        switch self {
        case .claude: return "#D97706"  // Orange
        case .openai: return "#10A37F"  // Green
        case .gemini: return "#4285F4"  // Blue
        }
    }
}
