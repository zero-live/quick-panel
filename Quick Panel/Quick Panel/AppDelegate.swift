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
            print("⚠️ Application already launched, ignoring duplicate launch")
            return
        }
        hasLaunched = true

        // Check for existing instances
        if !checkSingleInstance() {
            print("❌ Another instance is already running, exiting...")
            exit(0)
        }

        // Hide the default window
        NSApplication.shared.windows.first?.close()

        // Keep app running in background
        NSApp.setActivationPolicy(.accessory)

        print("🚀 Quick Panel starting...")
        print("💡 Running from: \(Bundle.main.bundlePath)")

        // Always setup services first (will use backup method if no permission)
        setupServices()

        // Check accessibility permission after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasPermission = PermissionManager.shared.checkAccessibilityPermission()
            print("📋 Final accessibility permission check: \(hasPermission)")

            if hasPermission {
                print("✅ Permission granted!")
            } else if self.mouseEventMonitor?.isUsingBackupMethod() == true {
                print("⚠️ Using backup method (NSEvent)")
                print("💡 App is working. If you want better reliability, grant accessibility permission.")
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
            print("⚠️ Cannot get bundle identifier")
            return true
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let instances = runningApps.filter { $0.bundleIdentifier == bundleID }

        print("🔍 Found \(instances.count) instance(s) of Quick Panel")

        // Should only find ourselves
        if instances.count > 1 {
            print("⚠️ Multiple instances detected:")
            for (index, app) in instances.enumerated() {
                print("  Instance \(index + 1): PID \(app.processIdentifier)")
            }
            return false
        }

        return true
    }
}
