import Foundation
import AppKit

struct VersionInfo {
    let current: String
    let latest: String
    let isNewer: Bool
    let downloadURL: String
}

@Observable
class Updater {
    static let shared = Updater()
    
    private let githubRepo = "multi-turn/ai-usage-monitor"
    private let appName = "AI Usage Monitor"
    
    var isChecking = false
    var isDownloading = false
    var downloadProgress: Double = 0
    var latestVersion: String?
    var updateAvailable = false
    var downloadURL: String?
    var error: String?
    
    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    private var githubAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
    }
    
    private init() {}
    
    @MainActor
    func checkForUpdates(force: Bool = false) async {
        guard !isChecking else { return }
        
        isChecking = true
        error = nil
        
        defer { isChecking = false }
        
        do {
            let versionInfo = try await fetchLatestRelease()
            latestVersion = versionInfo.latest
            updateAvailable = versionInfo.isNewer
            downloadURL = versionInfo.downloadURL
            
            if updateAvailable {
                showUpdateNotification(newVersion: versionInfo.latest)
            }
        } catch {
            self.error = error.localizedDescription
            print("Update check failed: \(error)")
        }
    }
    
    private func fetchLatestRelease() async throws -> VersionInfo {
        var request = URLRequest(url: githubAPIURL)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("AIUsageMonitor/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            throw UpdateError.parseError
        }
        
        let dmgAsset = assets.first { asset in
            (asset["name"] as? String)?.hasSuffix(".dmg") == true
        }
        
        guard let downloadURL = dmgAsset?["browser_download_url"] as? String else {
            throw UpdateError.noDownloadURL
        }
        
        let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        let isNewer = compareVersions(current: currentVersion, latest: latestVersion)
        
        return VersionInfo(
            current: currentVersion,
            latest: latestVersion,
            isNewer: isNewer,
            downloadURL: downloadURL
        )
    }
    
    private func compareVersions(current: String, latest: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(currentParts.count, latestParts.count) {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let latestPart = i < latestParts.count ? latestParts[i] : 0
            
            if latestPart > currentPart { return true }
            if latestPart < currentPart { return false }
        }
        
        return false
    }
    
    @MainActor
    func downloadAndInstall() async {
        guard let urlString = downloadURL,
              let url = URL(string: urlString) else {
            error = "No download URL available"
            return
        }
        
        isDownloading = true
        downloadProgress = 0
        error = nil
        
        do {
            let dmgPath = try await downloadDMG(from: url)
            try await install(dmgPath: dmgPath)
        } catch {
            self.error = error.localizedDescription
            isDownloading = false
        }
    }
    
    private func downloadDMG(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed
        }
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsURL.appendingPathComponent("\(appName).dmg")
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func install(dmgPath: URL) async throws {
        let appPath = Bundle.main.bundlePath
        let appDir = (appPath as NSString).deletingLastPathComponent
        
        guard FileManager.default.isWritableFile(atPath: appDir) else {
            throw UpdateError.noWritePermission
        }
        
        let mountPoint = "/tmp/AIUsageMonitor"
        let dmgPathStr = dmgPath.path
        
        _ = shell("mkdir -p \(mountPoint)")
        
        let mountResult = shell("/usr/bin/hdiutil attach \"\(dmgPathStr)\" -mountpoint \(mountPoint) -noverify -nobrowse -noautoopen")
        
        if mountResult.contains("is busy") {
            _ = shell("/usr/bin/hdiutil detach \(mountPoint)")
            _ = shell("/usr/bin/hdiutil attach \"\(dmgPathStr)\" -mountpoint \(mountPoint) -noverify -nobrowse -noautoopen")
        }
        
        let scriptPath = "\(mountPoint)/\(appName).app/Contents/Resources/Scripts/updater.sh"
        
        if FileManager.default.fileExists(atPath: scriptPath) {
            _ = shell("cp -f \"\(scriptPath)\" /tmp/updater.sh")
            shellAsync("sh /tmp/updater.sh --app \"\(appDir)\" --dmg \"\(dmgPathStr)\" --mount \"\(mountPoint)\" >/dev/null 2>&1 &")
        } else {
            _ = shell("rm -rf \"\(appPath)\"")
            _ = shell("cp -rf \"\(mountPoint)/\(appName).app\" \"\(appDir)/\"")
            _ = shell("/usr/bin/hdiutil detach \"\(mountPoint)\"")
            _ = shell("rm -f \"\(dmgPathStr)\"")
            
            shellAsync("open \"\(appDir)/\(appName).app\"")
        }
        
        exit(0)
    }
    
    private func showUpdateNotification(newVersion: String) {
        let notification = NSUserNotification()
        notification.title = "업데이트 가능"
        notification.informativeText = "AI Usage Monitor \(newVersion) 버전을 사용할 수 있습니다."
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @discardableResult
    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.standardInput = nil
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func shellAsync(_ command: String) {
        let task = Process()
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.standardInput = nil
        task.standardOutput = nil
        task.standardError = nil
        
        do {
            try task.run()
        } catch {
            print("Async shell failed: \(error)")
        }
    }
}

enum UpdateError: LocalizedError {
    case networkError
    case parseError
    case noDownloadURL
    case downloadFailed
    case noWritePermission
    
    var errorDescription: String? {
        switch self {
        case .networkError: return "네트워크 오류"
        case .parseError: return "응답 파싱 실패"
        case .noDownloadURL: return "다운로드 URL 없음"
        case .downloadFailed: return "다운로드 실패"
        case .noWritePermission: return "쓰기 권한 없음"
        }
    }
}
