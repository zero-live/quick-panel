//
//  AppLauncher.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa

class AppLauncher {
    static let shared = AppLauncher()

    private init() {}

    func launchApp(at path: String) {
        let url = URL(fileURLWithPath: path)

        do {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                if let error = error {
                    print("Failed to launch app at \(path): \(error.localizedDescription)")
                    self.showError(message: "无法启动应用: \(error.localizedDescription)")
                } else {
                    print("Successfully launched app at \(path)")
                }
            }
        }
    }

    func openWebsite(url: String, browserPath: String? = nil) {
        guard let websiteURL = URLNormalizer.normalizedURL(from: url) else {
            showError(message: "无效的网址")
            return
        }

        if let browserPath = browserPath {
            // Open with specific browser
            let browserURL = URL(fileURLWithPath: browserPath)
            let configuration = NSWorkspace.OpenConfiguration()

            NSWorkspace.shared.open([websiteURL], withApplicationAt: browserURL, configuration: configuration) { app, error in
                if let error = error {
                    print("Failed to open URL \(url) with browser \(browserPath): \(error.localizedDescription)")
                    self.showError(message: "无法打开网址: \(error.localizedDescription)")
                }
            }
        } else {
            // Open with default browser
            NSWorkspace.shared.open(websiteURL)
        }
    }

    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "错误"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
