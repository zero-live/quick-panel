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
        print("🔄 Active application changed")
        updateCurrentApp()
    }

    private func updateCurrentApp() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = frontmostApp.bundleIdentifier else {
            print("⚠️ No frontmost application found")
            applyFrontmostApp(nil)
            return
        }

        let appName = frontmostApp.localizedName ?? "当前应用"
        let appInfo = FrontmostAppInfo(bundleIdentifier: bundleIdentifier, appName: appName)

        if isOwnApplication(bundleIdentifier) {
            if let lastExternalFrontmostAppInfo {
                print("↩️ Ignoring self app activation, keep context: \(lastExternalFrontmostAppInfo.appName) (\(lastExternalFrontmostAppInfo.bundleIdentifier))")
                applyFrontmostApp(lastExternalFrontmostAppInfo)
            } else {
                print("⚠️ Frontmost app is Quick Panel and no external context is cached")
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

        print("👀 Current app: \(appInfo.appName) (\(appInfo.bundleIdentifier))")

        if let preset = PresetConfiguration.shared.getPreset(for: appInfo.bundleIdentifier) {
            print("✅ Found preset for \(preset.appName)")
            currentApp = preset
            currentActions = preset.actions
        } else {
            print("ℹ️ No preset found for \(appInfo.bundleIdentifier)")
            currentApp = nil
            currentActions = []
        }
    }
}

struct FrontmostAppInfo: Equatable {
    let bundleIdentifier: String
    let appName: String
}
