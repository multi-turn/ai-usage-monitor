import AppKit
import SwiftUI

@MainActor
enum MenuBarIconRenderer {

    private static var isDarkMode: Bool {
        let appearance = NSApp.effectiveAppearance
        switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
        case .darkAqua: return true
        default: return false
        }
    }

    static func render(appState: AppState, themeManager: ThemeManager) -> NSImage {
        let services = appState.services.filter { $0.config.isEnabled }
        guard !services.isEmpty else {
            return NSImage(size: NSSize(width: 22, height: 22))
        }

        let serviceWidth: CGFloat = 38
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(services.count) * serviceWidth + CGFloat(services.count - 1) * spacing
        let height: CGFloat = 22

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()
        defer { image.unlockFocus() }

        let dark = isDarkMode

        var x: CGFloat = 0
        for service in services {
            drawStatsStyleMeter(at: x, service: service, dark: dark, width: serviceWidth, height: height)
            x += serviceWidth + spacing
        }

        image.isTemplate = false
        return image
    }

    private static func drawStatsStyleMeter(
        at x: CGFloat,
        service: ServiceViewModel,
        dark: Bool,
        width: CGFloat,
        height: CGFloat
    ) {
        let color = service.config.serviceType.brandColor.nsColor
        let labelColor = dark ? NSColor.white.withAlphaComponent(0.90) : NSColor.black.withAlphaComponent(0.78)
        let borderColor = dark ? NSColor.white.withAlphaComponent(0.55) : NSColor.black.withAlphaComponent(0.35)
        let emptyBarColor = dark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08)

        let fiveHourRemaining = max(0, 100.0 - (service.fiveHourUsage ?? service.usagePercentage)) / 100.0
        let sevenDayRemaining = max(0, 100.0 - (service.sevenDayUsage ?? service.usagePercentage)) / 100.0

        let label: String
        switch service.config.serviceType {
        case .claude: label = "Claude"
        case .codex: label = "Codex"
        case .gemini: label = "Gemini"
        }

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: labelColor,
        ]

        let labelSize = label.size(withAttributes: labelAttrs)
        NSAttributedString(string: label, attributes: labelAttrs)
            .draw(at: NSPoint(x: x + (width - labelSize.width) / 2, y: height - 9))

        let barCount = 10
        let barAreaWidth = width - 4
        let barWidth: CGFloat = (barAreaWidth - CGFloat(barCount - 1) * 1) / CGFloat(barCount)
        let maxBarHeight: CGFloat = 10
        let barY: CGFloat = 2

        let barHeight = maxBarHeight * max(0.2, CGFloat(sevenDayRemaining))

        let frameRect = NSRect(x: x + 1, y: barY - 1, width: barAreaWidth + 2, height: maxBarHeight + 2)
        let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 2, yRadius: 2)
        borderColor.setStroke()
        framePath.lineWidth = 0.75
        framePath.stroke()

        for i in 0..<barCount {
            let barX = x + 2 + CGFloat(i) * (barWidth + 1)
            let fillRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)

            let barPosition = CGFloat(i + 1) / CGFloat(barCount)
            let shouldFill = barPosition <= CGFloat(fiveHourRemaining) + 0.05

            if shouldFill {
                color.setFill()
            } else {
                emptyBarColor.setFill()
            }

            NSBezierPath(rect: fillRect).fill()
        }
    }
}

extension Color {
    var nsColor: NSColor { NSColor(self) }
}
