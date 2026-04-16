//
//  ContextDetector.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import Combine

class ContextDetector: ObservableObject {
    static let shared = ContextDetector()

    @Published var currentApp: AppPreset?
    @Published var currentActions: [ContextAction] = []
    @Published var frontmostAppInfo: FrontmostAppInfo?

    private let ownBundleIdentifier = Bundle.main.bundleIdentifier
    private var lastExternalFrontmostAppInfo: FrontmostAppInfo?
    private let logCategory: AppLogCategory = .app

    private init() {
        setupNotifications()
        updateCurrentApp()
    }

    private func setupNotifications() {
        // Listen for application activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        updateCurrentApp()
    }

    private func updateCurrentApp() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmostApp.bundleIdentifier else {
            AppLogger.debug("未识别到当前前台应用。", category: logCategory)
            applyFrontmostApp(nil)
            return
        }

        let appName = frontmostApp.localizedName ?? "当前应用"
        let appInfo = FrontmostAppInfo(bundleIdentifier: bundleIdentifier, appName: appName)

        if isOwnApplication(bundleIdentifier) {
            if let lastExternalFrontmostAppInfo {
                AppLogger.debug("忽略 Quick Panel 自身激活，沿用外部应用：\(lastExternalFrontmostAppInfo.bundleIdentifier)。", category: logCategory)
                applyFrontmostApp(lastExternalFrontmostAppInfo)
            } else {
                AppLogger.debug("前台应用是 Quick Panel，且没有缓存的外部应用上下文。", category: logCategory)
                applyFrontmostApp(nil)
            }
            return
        }

        lastExternalFrontmostAppInfo = appInfo
        applyFrontmostApp(appInfo)
    }

    func refreshCurrentApp() {
        updateCurrentApp()
    }

    private func isOwnApplication(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier == ownBundleIdentifier
    }

    private func applyFrontmostApp(_ appInfo: FrontmostAppInfo?) {
        frontmostAppInfo = appInfo

        guard let appInfo else {
            currentApp = nil
            currentActions = []
            return
        }

        AppLogger.debug("当前前台应用更新为：\(appInfo.bundleIdentifier)。", category: logCategory)

        if let preset = PresetConfiguration.shared.getPreset(for: appInfo.bundleIdentifier) {
            currentApp = preset
            currentActions = preset.actions
        } else {
            currentApp = nil
            currentActions = []
        }
    }
}

struct FrontmostAppInfo: Equatable {
    let bundleIdentifier: String
    let appName: String
}
