//
//  UpdateManager.swift
//  Quick Panel
//
//  Created by Claude on 2026/3/8.
//

import Foundation
import AppKit
import Combine

class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var isChecking = false
    @Published var latestVersion: String? = nil
    @Published var downloadURL: String? = nil
    @Published var releaseNotes: String? = nil
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var lastCheckedAt: Date? = nil
    @Published var lastErrorMessage: String? = nil

    private let giteeReleasesAPI = "https://gitee.com/api/v5/repos/zerolive/quick-panel/releases/latest"
    private let releasePageURL = "https://gitee.com/zerolive/quick-panel/releases"
    private let expectedAssetNamePrefix = "Quick Panel"
    private let logCategory: AppLogCategory = .app

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        return isNewerVersion(latest, than: currentVersion) && latest != skippedVersion
    }

    private init() {}

    var skippedVersion: String? {
        SettingsManager.shared.settings.skippedUpdateVersion
    }

    var canAutoCheck: Bool {
        SettingsManager.shared.settings.autoCheckForUpdates
    }

    private func isNewerVersion(_ version: String, than current: String) -> Bool {
        let latestParts = version.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(latestParts.count, currentParts.count)
        for i in 0..<maxLen {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    private func normalizedVersion(from tagName: String) -> String {
        tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "refs/tags/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    private func bestDownloadURL(from assets: [[String: Any]]) -> String? {
        let dmgAssets = assets.filter { asset in
            let name = asset["name"] as? String ?? ""
            return name.lowercased().hasSuffix(".dmg")
        }

        if let preferred = dmgAssets.first(where: { asset in
            let name = asset["name"] as? String ?? ""
            return name.hasPrefix(expectedAssetNamePrefix)
        }) {
            return preferred["browser_download_url"] as? String
        }

        if let firstDMG = dmgAssets.first {
            return firstDMG["browser_download_url"] as? String
        }

        return assets.first?["browser_download_url"] as? String
    }

    private func persistLastCheckedAt(_ date: Date) {
        SettingsManager.shared.batchUpdate { settings in
            settings.lastUpdateCheckAt = date
        }
        lastCheckedAt = date
    }

    func refreshStateFromSettings() {
        lastCheckedAt = SettingsManager.shared.settings.lastUpdateCheckAt
    }

    func skipCurrentLatestVersion() {
        guard let latestVersion else { return }
        SettingsManager.shared.batchUpdate { settings in
            settings.skippedUpdateVersion = latestVersion
        }
        objectWillChange.send()
    }

    func clearSkippedVersion() {
        SettingsManager.shared.batchUpdate { settings in
            settings.skippedUpdateVersion = nil
        }
        objectWillChange.send()
    }

    func performAutomaticCheckIfNeeded() {
        refreshStateFromSettings()
        guard canAutoCheck else {
            AppLogger.debug("已关闭自动检查更新，跳过本次静默检查。", category: logCategory)
            return
        }
        checkForUpdates(silent: true)
    }

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        lastErrorMessage = nil

        guard let url = URL(string: giteeReleasesAPI) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false
                self.persistLastCheckedAt(Date())

                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.lastErrorMessage = "无法连接到更新服务器，请稍后再试。"
                    AppLogger.error("检查更新失败：网络请求或解析失败。", category: self.logCategory)
                    if !silent {
                        self.showAlert(title: "检查失败", message: self.lastErrorMessage ?? "无法连接到更新服务器，请稍后再试。")
                    }
                    return
                }

                let tagName = self.normalizedVersion(from: json["tag_name"] as? String ?? "")
                guard !tagName.isEmpty else {
                    self.lastErrorMessage = "更新服务器返回了无效的版本信息。"
                    AppLogger.error("检查更新失败：tag_name 为空或无效。", category: self.logCategory)
                    if !silent {
                        self.showAlert(title: "检查失败", message: self.lastErrorMessage ?? "更新服务器返回了无效的版本信息。")
                    }
                    return
                }

                self.latestVersion = tagName
                self.releaseNotes = json["body"] as? String

                if let assets = json["assets"] as? [[String: Any]] {
                    self.downloadURL = self.bestDownloadURL(from: assets)
                } else {
                    self.downloadURL = nil
                }

                if self.hasUpdate {
                    AppLogger.notice("发现新版本：\(tagName)。", category: self.logCategory)
                    self.showUpdateAlert()
                } else if !silent {
                    self.showAlert(title: "已是最新版本", message: "当前版本 \(self.currentVersion) 已是最新版本。")
                }
            }
        }.resume()
    }

    private func showUpdateAlert() {
        guard let latest = latestVersion else { return }

        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(latest)"
        alert.informativeText = releaseNotes.map { notes in
            notes.count > 200 ? String(notes.prefix(200)) + "..." : notes
        } ?? "有新版本可用，是否立即下载更新？"
        alert.addButton(withTitle: "立即更新")
        alert.addButton(withTitle: "跳过此版本")
        alert.addButton(withTitle: "稍后提醒")
        alert.alertStyle = .informational

        if let appIcon = NSApplication.shared.applicationIconImage {
            alert.icon = appIcon
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            downloadAndInstall()
        } else if response == .alertSecondButtonReturn {
            skipCurrentLatestVersion()
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    func downloadAndInstall() {
        guard let urlString = downloadURL, let url = URL(string: urlString) else {
            lastErrorMessage = "未找到可用安装包，已为你打开发布页。"
            if let releasePage = URL(string: releasePageURL) {
                NSWorkspace.shared.open(releasePage)
            }
            return
        }

        isDownloading = true
        downloadProgress = 0

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }
            self.isDownloading = false

            guard let tempURL = tempURL, error == nil else {
                DispatchQueue.main.async {
                    self.lastErrorMessage = "无法下载更新文件，请手动前往 Gitee 下载。"
                    AppLogger.error("更新包下载失败。", category: self.logCategory)
                    self.showAlert(title: "下载失败", message: "无法下载更新文件，请手动前往 Gitee 下载。")
                }
                return
            }

            let dmgName = url.lastPathComponent
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(dmgName)
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.moveItem(at: tempURL, to: destURL)

            DispatchQueue.main.async {
                self.lastErrorMessage = nil
                AppLogger.notice("更新包下载完成，已打开安装文件：\(dmgName)。", category: self.logCategory)
                NSWorkspace.shared.open(destURL)
            }
        }
        task.resume()
    }

    func openReleasePage() {
        guard let url = URL(string: releasePageURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
