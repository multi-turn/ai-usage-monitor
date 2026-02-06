import SwiftUI

enum ThemeMode: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct AppTheme {
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let text: Color
    let secondaryText: Color
    let border: Color
    let divider: Color

    static let dark = AppTheme(
        background: Color(red: 0.08, green: 0.08, blue: 0.14),
        secondaryBackground: Color(red: 0.12, green: 0.12, blue: 0.2),
        cardBackground: Color.white.opacity(0.06),
        text: .white,
        secondaryText: Color.white.opacity(0.6),
        border: Color.white.opacity(0.1),
        divider: Color.white.opacity(0.08)
    )

    static let light = AppTheme(
        background: Color(red: 0.96, green: 0.96, blue: 0.98),
        secondaryBackground: Color.white,
        cardBackground: Color.white,
        text: Color(red: 0.1, green: 0.1, blue: 0.15),
        secondaryText: Color(red: 0.4, green: 0.4, blue: 0.45),
        border: Color.black.opacity(0.08),
        divider: Color.black.opacity(0.06)
    )
}

@Observable
class ThemeManager {
    static let shared = ThemeManager()

    var mode: ThemeMode {
        didSet { save() }
    }

    var current: AppTheme {
        switch effectiveMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return .dark
        }
    }

    var effectiveMode: ThemeMode {
        guard mode == .system else { return mode }
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        self.mode = ThemeMode(rawValue: saved) ?? .system
    }

    private func save() {
        UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
    }
}
