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
            frontmostAppInfo = nil
            currentApp = nil
            currentActions = []
            return
        }

        let appName = frontmostApp.localizedName ?? "当前应用"
        frontmostAppInfo = FrontmostAppInfo(bundleIdentifier: bundleIdentifier, appName: appName)
        print("👀 Current app: \(appName) (\(bundleIdentifier))")

        // Check if we have a preset for this app
        if let preset = PresetConfiguration.shared.getPreset(for: bundleIdentifier) {
            print("✅ Found preset for \(preset.appName)")
            currentApp = preset
            currentActions = preset.actions
        } else {
            print("ℹ️ No preset found for \(bundleIdentifier)")
            currentApp = nil
            currentActions = []
        }
    }

    func refreshCurrentApp() {
        updateCurrentApp()
    }
}

struct FrontmostAppInfo: Equatable {
    let bundleIdentifier: String
    let appName: String
}
