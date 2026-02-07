import AppKit
import Observation

@MainActor
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let statusItem: NSStatusItem
    private let appState: AppState
    private let themeManager: ThemeManager

    private var localEventMonitor: EventMonitor?
    private var globalEventMonitor: EventMonitor?
    private var appearanceObservation: NSKeyValueObservation?

    init(title: String, appState: AppState, themeManager: ThemeManager) {
        self.appState = appState
        self.themeManager = themeManager

        let panel = MenuBarPanelWindow(title: title) {
            ContentView(appState: appState)
        }
        self.window = panel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        super.init()

        statusItem.button?.setAccessibilityTitle(title)
        updateStatusItemImage()

        localEventMonitor = LocalEventMonitor(mask: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            if let button = self.statusItem.button,
               event.window == button.window,
               !event.modifierFlags.contains(.command) {
                self.didPressStatusBarButton(button)
                return nil
            }
            return event
        }

        globalEventMonitor = GlobalEventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            if self.window.isKeyWindow {
                self.window.resignKey()
            }
        }

        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                self?.updateStatusItemImage()
            }
        }

        window.delegate = self
        localEventMonitor?.start()

        startIconObservationLoop()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func startIconObservationLoop() {
        withObservationTracking {
            _ = appState.isRefreshing
            _ = appState.lastRefreshDate
            _ = themeManager.current.menuBar
            for service in appState.services {
                _ = service.config.isEnabled
                _ = service.usagePercentage
                _ = service.fiveHourUsage
                _ = service.sevenDayUsage
            }
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItemImage()
                self?.startIconObservationLoop()
            }
        }
    }

    private func updateStatusItemImage() {
        statusItem.button?.image = MenuBarIconRenderer.render(appState: appState, themeManager: themeManager)
        statusItem.button?.imagePosition = .imageOnly
    }

    private func didPressStatusBarButton(_ sender: NSStatusBarButton) {
        if window.isVisible {
            dismissWindow()
            return
        }

        setWindowPosition()

        DistributedNotificationCenter.default().post(name: .beginMenuTracking, object: nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        globalEventMonitor?.start()
        statusItem.button?.highlight(true)
    }

    func windowDidResignKey(_ notification: Notification) {
        globalEventMonitor?.stop()
        dismissWindow()
    }

    private func dismissWindow() {
        DistributedNotificationCenter.default().post(name: .endMenuTracking, object: nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window.orderOut(nil)
            self?.window.alphaValue = 1
            self?.statusItem.button?.highlight(false)
        }
    }

    private func setWindowPosition() {
        guard let statusItemWindow = statusItem.button?.window else {
            window.center()
            return
        }

        var targetRect = statusItemWindow.frame

        if let screen = statusItemWindow.screen {
            let windowWidth = window.frame.width
            if statusItemWindow.frame.origin.x + windowWidth > screen.visibleFrame.width {
                targetRect.origin.x += statusItemWindow.frame.width
                targetRect.origin.x -= windowWidth
                targetRect.origin.x += Metrics.windowBorderSize
            } else {
                targetRect.origin.x -= Metrics.windowBorderSize
            }
        } else {
            targetRect.origin.x -= Metrics.windowBorderSize
        }

        window.setFrameTopLeftPoint(targetRect.origin)
    }
}

private extension Notification.Name {
    static let beginMenuTracking = Notification.Name("com.apple.HIToolbox.beginMenuTrackingNotification")
    static let endMenuTracking = Notification.Name("com.apple.HIToolbox.endMenuTrackingNotification")
}

private enum Metrics {
    static let windowBorderSize: CGFloat = 2
}
