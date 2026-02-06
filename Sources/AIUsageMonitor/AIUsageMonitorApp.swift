import SwiftUI
import AppKit

@main
struct AIUsageMonitorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView(appState: appState)
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @Bindable var appState: AppState

    var body: some View {
        Image(nsImage: renderMenuBarImage())
    }

    private var enabledServices: [ServiceViewModel] {
        appState.services.filter { $0.config.isEnabled }
    }

    private func renderMenuBarImage() -> NSImage {
        let services = enabledServices
        guard !services.isEmpty else {
            return NSImage(size: NSSize(width: 22, height: 22))
        }

        // Stats-style: label + bar chart for each service
        let serviceWidth: CGFloat = 38
        let spacing: CGFloat = 6
        let totalWidth = CGFloat(services.count) * serviceWidth + CGFloat(services.count - 1) * spacing
        let height: CGFloat = 22

        let image = NSImage(size: NSSize(width: totalWidth, height: height))
        image.lockFocus()

        var x: CGFloat = 0
        for service in services {
            drawStatsStyleMeter(at: x, service: service, width: serviceWidth, height: height)
            x += serviceWidth + spacing
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawStatsStyleMeter(at x: CGFloat, service: ServiceViewModel, width: CGFloat, height: CGFloat) {
        let color = serviceColor(for: service)

        // X-axis: 5-hour remaining (how many bars filled)
        let fiveHourRemaining = max(0, 100.0 - (service.fiveHourUsage ?? service.usagePercentage)) / 100.0
        // Y-axis: 7-day remaining (bar height)
        let sevenDayRemaining = max(0, 100.0 - (service.sevenDayUsage ?? service.usagePercentage)) / 100.0

        // Draw label
        let label = service.config.serviceType == .claude ? "Claude" : "Codex"
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let labelSize = label.size(withAttributes: labelAttrs)
        let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
        labelStr.draw(at: NSPoint(x: x + (width - labelSize.width) / 2, y: height - 9))

        // Draw bar chart (10 vertical bars)
        let barCount = 10
        let barAreaWidth = width - 4
        let barWidth: CGFloat = (barAreaWidth - CGFloat(barCount - 1) * 1) / CGFloat(barCount)
        let maxBarHeight: CGFloat = 10
        let barY: CGFloat = 2

        // Bar height based on 7-day remaining (minimum 20% height for visibility)
        let barHeight = maxBarHeight * max(0.2, CGFloat(sevenDayRemaining))

        let frameRect = NSRect(x: x + 1, y: barY - 1, width: barAreaWidth + 2, height: maxBarHeight + 2)
        let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 2, yRadius: 2)
        NSColor.white.setStroke()
        framePath.lineWidth = 0.5
        framePath.stroke()

        for i in 0..<barCount {
            let barX = x + 2 + CGFloat(i) * (barWidth + 1)

            // Draw filled bar
            let fillRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)

            // Fill based on 5-hour remaining percentage
            let barPosition = CGFloat(i + 1) / CGFloat(barCount)
            let shouldFill = barPosition <= CGFloat(fiveHourRemaining) + 0.05
            if shouldFill {
                color.setFill()
            } else {
                NSColor.white.withAlphaComponent(0.08).setFill()
            }
            NSBezierPath(rect: fillRect).fill()
        }
    }

    private func serviceColor(for service: ServiceViewModel) -> NSColor {
        switch service.config.serviceType {
        case .claude: return NSColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1.0)   // Orange
        case .codex: return NSColor(red: 0.1, green: 0.7, blue: 0.55, alpha: 1.0)  // Teal
        }
    }
}

// Extension to convert SwiftUI Color to NSColor
extension Color {
    var nsColor: NSColor {
        NSColor(self)
    }
}
