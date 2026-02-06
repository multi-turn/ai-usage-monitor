import Foundation

#if ENABLE_SPARKLE
import Sparkle

@MainActor
final class SparkleUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        guard Self.isProperAppBundle() else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? true }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    private static func isProperAppBundle() -> Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }
}
#endif

@MainActor
@Observable
class Updater {
    static let shared = Updater()

    #if ENABLE_SPARKLE
    let sparkle = SparkleUpdater()
    #endif

    var updateAvailable = false
    var latestVersion: String?
    var error: String?

    private let githubRepo = "multi-turn/ai-usage-monitor"

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private init() {}

    func checkForUpdates() {
        #if ENABLE_SPARKLE
        sparkle.checkForUpdates()
        #else
        Task { await checkGitHub() }
        #endif
    }

    private func checkGitHub() async {
        let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            return
        }

        let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        latestVersion = latest
        updateAvailable = compareVersions(current: currentVersion, latest: latest)
    }

    private nonisolated func compareVersions(current: String, latest: String) -> Bool {
        let c = current.split(separator: ".").compactMap { Int($0) }
        let l = latest.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(c.count, l.count) {
            let cv = i < c.count ? c[i] : 0
            let lv = i < l.count ? l[i] : 0
            if lv > cv { return true }
            if lv < cv { return false }
        }
        return false
    }
}
