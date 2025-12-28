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
            currentApp = nil
            currentActions = []
            return
        }

        print("👀 Current app: \(frontmostApp.localizedName ?? "Unknown") (\(bundleIdentifier))")

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
