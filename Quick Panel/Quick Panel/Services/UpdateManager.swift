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

    private let giteeReleasesAPI = "https://gitee.com/api/v5/repos/zerolive/quick-panel/releases/latest"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var hasUpdate: Bool {
        guard let latest = latestVersion else { return false }
        return isNewerVersion(latest, than: currentVersion)
    }

    private init() {}

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

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

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

                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    if !silent {
                        self.showAlert(title: "检查失败", message: "无法连接到更新服务器，请稍后再试。")
                    }
                    return
                }

                let tagName = (json["tag_name"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                self.latestVersion = tagName
                self.releaseNotes = json["body"] as? String

                if let assets = json["assets"] as? [[String: Any]] {
                    self.downloadURL = assets.first(where: {
                        ($0["name"] as? String ?? "").hasSuffix(".dmg")
                    })?["browser_download_url"] as? String
                        ?? assets.first?["browser_download_url"] as? String
                }

                if self.hasUpdate {
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
        alert.addButton(withTitle: "稍后提醒")
        alert.alertStyle = .informational

        if let appIcon = NSApplication.shared.applicationIconImage {
            alert.icon = appIcon
        }

        if alert.runModal() == .alertFirstButtonReturn {
            downloadAndInstall()
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
            if let releasePage = URL(string: "https://gitee.com/zerolive/quick-panel/releases") {
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
                    self.showAlert(title: "下载失败", message: "无法下载更新文件，请手动前往 Gitee 下载。")
                }
                return
            }

            let dmgName = url.lastPathComponent
            let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(dmgName)
            try? FileManager.default.removeItem(at: destURL)
            try? FileManager.default.moveItem(at: tempURL, to: destURL)

            DispatchQueue.main.async {
                NSWorkspace.shared.open(destURL)
            }
        }
        task.resume()
    }
}
