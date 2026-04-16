//
//  AppDelegate.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var mouseEventMonitor: MouseEventMonitor?
    var hotkeyManager: HotkeyManager?

    private var hasLaunched = false
    private var hasPromptedForAccessibility = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple launches
        if hasLaunched {
            return
        }
        hasLaunched = true

        // Check for existing instances
        if !checkSingleInstance() {
            exit(0)
        }

        // Hide the default window
        NSApplication.shared.windows.first?.close()

        // Keep app running in background
        NSApp.setActivationPolicy(.accessory)


        // Always setup services first (will use backup method if no permission)
        setupServices()

        // Check accessibility permission after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasPermission = PermissionManager.shared.checkAccessibilityPermission()

            if hasPermission {
            } else if self.mouseEventMonitor?.isUsingBackupMethod() == true {
                self.promptForAccessibilityIfNeeded()
            }
        }
    }

    private func setupServices() {
        // Load settings
        _ = SettingsManager.shared

        // Setup status bar
        StatusBarManager.shared.setupStatusBar()

        // Apply launch at login setting
        let settings = SettingsManager.shared.settings
        if settings.launchAtLogin {
            _ = LoginItemManager.shared.setLaunchAtLogin(true)
        }

        // Initialize panel window manager
        _ = PanelWindowManager.shared

        // Initialize mouse event monitor
        mouseEventMonitor = MouseEventMonitor { [weak self] location in
            self?.handleMiddleClick(at: location)
        }

        mouseEventMonitor?.start()

        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            UpdateManager.shared.checkForUpdates(silent: true)
        }
    }

    private func handleMiddleClick(at location: CGPoint) {
        PanelWindowManager.shared.togglePanel(at: location)
    }

    private func promptForAccessibilityIfNeeded() {
        guard !hasPromptedForAccessibility else { return }
        hasPromptedForAccessibility = true
        PermissionManager.shared.requestAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mouseEventMonitor?.stop()
        hotkeyManager?.stop()
    }

    private func checkSingleInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return true
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let instances = runningApps.filter { $0.bundleIdentifier == bundleID }


        // Should only find ourselves
        if instances.count > 1 {
            for (index, app) in instances.enumerated() {
            }
            return false
        }

        return true
    }
}
