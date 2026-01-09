import Foundation

enum Language: String, CaseIterable, Codable {
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    case chinese = "zh"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case russian = "ru"
    case italian = "it"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .italian: return "Italiano"
        }
    }
}

@Observable
class LocalizationManager {
    static let shared = LocalizationManager()

    var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = Language(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .english
        }
    }

    // MARK: - Localized Strings

    var aiUsage: String {
        switch currentLanguage {
        case .english: return "AI Usage"
        case .korean: return "AI 사용량"
        case .japanese: return "AI使用量"
        case .chinese: return "AI使用量"
        case .spanish: return "Uso de IA"
        case .french: return "Utilisation IA"
        case .german: return "KI-Nutzung"
        case .portuguese: return "Uso de IA"
        case .russian: return "Использование ИИ"
        case .italian: return "Utilizzo IA"
        }
    }

    var settings: String {
        switch currentLanguage {
        case .english: return "Settings"
        case .korean: return "설정"
        case .japanese: return "設定"
        case .chinese: return "设置"
        case .spanish: return "Ajustes"
        case .french: return "Paramètres"
        case .german: return "Einstellungen"
        case .portuguese: return "Configurações"
        case .russian: return "Настройки"
        case .italian: return "Impostazioni"
        }
    }

    var updating: String {
        switch currentLanguage {
        case .english: return "Updating..."
        case .korean: return "업데이트 중..."
        case .japanese: return "更新中..."
        case .chinese: return "更新中..."
        case .spanish: return "Actualizando..."
        case .french: return "Mise à jour..."
        case .german: return "Aktualisiere..."
        case .portuguese: return "Atualizando..."
        case .russian: return "Обновление..."
        case .italian: return "Aggiornamento..."
        }
    }

    var lastUpdate: String {
        switch currentLanguage {
        case .english: return "Updated"
        case .korean: return "업데이트"
        case .japanese: return "更新"
        case .chinese: return "更新"
        case .spanish: return "Actualizado"
        case .french: return "Mis à jour"
        case .german: return "Aktualisiert"
        case .portuguese: return "Atualizado"
        case .russian: return "Обновлено"
        case .italian: return "Aggiornato"
        }
    }

    var ago: String {
        switch currentLanguage {
        case .english: return "ago"
        case .korean: return "전"
        case .japanese: return "前"
        case .chinese: return "前"
        case .spanish: return "hace"
        case .french: return "il y a"
        case .german: return "vor"
        case .portuguese: return "atrás"
        case .russian: return "назад"
        case .italian: return "fa"
        }
    }

    // Time formatting
    func formatMinutes(_ minutes: Int) -> String {
        switch currentLanguage {
        case .english: return "\(minutes)m"
        case .korean: return "\(minutes)분"
        case .japanese: return "\(minutes)分"
        case .chinese: return "\(minutes)分钟"
        case .spanish: return "\(minutes)min"
        case .french: return "\(minutes)min"
        case .german: return "\(minutes)Min"
        case .portuguese: return "\(minutes)min"
        case .russian: return "\(minutes)мин"
        case .italian: return "\(minutes)min"
        }
    }

    func formatHours(_ hours: Int) -> String {
        switch currentLanguage {
        case .english: return "\(hours)h"
        case .korean: return "\(hours)시간"
        case .japanese: return "\(hours)時間"
        case .chinese: return "\(hours)小时"
        case .spanish: return "\(hours)h"
        case .french: return "\(hours)h"
        case .german: return "\(hours)Std"
        case .portuguese: return "\(hours)h"
        case .russian: return "\(hours)ч"
        case .italian: return "\(hours)h"
        }
    }

    func formatDays(_ days: Int) -> String {
        switch currentLanguage {
        case .english: return "\(days)d"
        case .korean: return "\(days)일"
        case .japanese: return "\(days)日"
        case .chinese: return "\(days)天"
        case .spanish: return "\(days)d"
        case .french: return "\(days)j"
        case .german: return "\(days)T"
        case .portuguese: return "\(days)d"
        case .russian: return "\(days)д"
        case .italian: return "\(days)g"
        }
    }

    func formatHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
        if hours > 0 && minutes > 0 {
            return "\(formatHours(hours)) \(formatMinutes(minutes))"
        } else if hours > 0 {
            return formatHours(hours)
        } else {
            return formatMinutes(minutes)
        }
    }

    func formatDaysHours(_ days: Int, _ hours: Int) -> String {
        if days > 0 && hours > 0 {
            return "\(formatDays(days)) \(formatHours(hours))"
        } else if days > 0 {
            return formatDays(days)
        } else {
            return formatHours(hours)
        }
    }

    // "resets in X time" format
    func formatResetTime(_ text: String) -> String {
        switch currentLanguage {
        case .english: return "resets in \(text)"
        case .korean: return "\(text) 후 재설정"
        case .japanese: return "\(text)後にリセット"
        case .chinese: return "\(text)后重置"
        case .spanish: return "reinicia en \(text)"
        case .french: return "réinitialise dans \(text)"
        case .german: return "Reset in \(text)"
        case .portuguese: return "reinicia em \(text)"
        case .russian: return "сброс через \(text)"
        case .italian: return "reset tra \(text)"
        }
    }

    // Settings labels
    var language: String {
        switch currentLanguage {
        case .english: return "Language"
        case .korean: return "언어"
        case .japanese: return "言語"
        case .chinese: return "语言"
        case .spanish: return "Idioma"
        case .french: return "Langue"
        case .german: return "Sprache"
        case .portuguese: return "Idioma"
        case .russian: return "Язык"
        case .italian: return "Lingua"
        }
    }

    var refreshInterval: String {
        switch currentLanguage {
        case .english: return "Refresh Interval"
        case .korean: return "새로고침 간격"
        case .japanese: return "更新間隔"
        case .chinese: return "刷新间隔"
        case .spanish: return "Intervalo de actualización"
        case .french: return "Intervalle de rafraîchissement"
        case .german: return "Aktualisierungsintervall"
        case .portuguese: return "Intervalo de atualização"
        case .russian: return "Интервал обновления"
        case .italian: return "Intervallo di aggiornamento"
        }
    }

    var launchAtLogin: String {
        switch currentLanguage {
        case .english: return "Launch at Login"
        case .korean: return "로그인 시 실행"
        case .japanese: return "ログイン時に起動"
        case .chinese: return "登录时启动"
        case .spanish: return "Iniciar al iniciar sesión"
        case .french: return "Lancer au démarrage"
        case .german: return "Bei Anmeldung starten"
        case .portuguese: return "Iniciar no login"
        case .russian: return "Запускать при входе"
        case .italian: return "Avvia al login"
        }
    }

    var services: String {
        switch currentLanguage {
        case .english: return "Services"
        case .korean: return "서비스"
        case .japanese: return "サービス"
        case .chinese: return "服务"
        case .spanish: return "Servicios"
        case .french: return "Services"
        case .german: return "Dienste"
        case .portuguese: return "Serviços"
        case .russian: return "Сервисы"
        case .italian: return "Servizi"
        }
    }

    var general: String {
        switch currentLanguage {
        case .english: return "General"
        case .korean: return "일반"
        case .japanese: return "一般"
        case .chinese: return "通用"
        case .spanish: return "General"
        case .french: return "Général"
        case .german: return "Allgemein"
        case .portuguese: return "Geral"
        case .russian: return "Общие"
        case .italian: return "Generale"
        }
    }

    var enabled: String {
        switch currentLanguage {
        case .english: return "Enabled"
        case .korean: return "활성화"
        case .japanese: return "有効"
        case .chinese: return "已启用"
        case .spanish: return "Habilitado"
        case .french: return "Activé"
        case .german: return "Aktiviert"
        case .portuguese: return "Ativado"
        case .russian: return "Включено"
        case .italian: return "Attivato"
        }
    }

    var minutes: String {
        switch currentLanguage {
        case .english: return "minutes"
        case .korean: return "분"
        case .japanese: return "分"
        case .chinese: return "分钟"
        case .spanish: return "minutos"
        case .french: return "minutes"
        case .german: return "Minuten"
        case .portuguese: return "minutos"
        case .russian: return "минут"
        case .italian: return "minuti"
        }
    }

    var usageHistory: String {
        switch currentLanguage {
        case .english: return "Usage History"
        case .korean: return "사용량 기록"
        case .japanese: return "使用履歴"
        case .chinese: return "使用记录"
        case .spanish: return "Historial de uso"
        case .french: return "Historique"
        case .german: return "Nutzungsverlauf"
        case .portuguese: return "Histórico"
        case .russian: return "История"
        case .italian: return "Cronologia"
        }
    }

    var hours24: String {
        switch currentLanguage {
        case .english: return "24h"
        case .korean: return "24시간"
        case .japanese: return "24時間"
        case .chinese: return "24小时"
        case .spanish: return "24h"
        case .french: return "24h"
        case .german: return "24h"
        case .portuguese: return "24h"
        case .russian: return "24ч"
        case .italian: return "24h"
        }
    }

    var days7: String {
        switch currentLanguage {
        case .english: return "7d"
        case .korean: return "7일"
        case .japanese: return "7日"
        case .chinese: return "7天"
        case .spanish: return "7d"
        case .french: return "7j"
        case .german: return "7T"
        case .portuguese: return "7d"
        case .russian: return "7д"
        case .italian: return "7g"
        }
    }
}

// Global accessor
let L = LocalizationManager.shared
