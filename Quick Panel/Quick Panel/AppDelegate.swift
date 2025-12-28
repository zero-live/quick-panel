//
//  AppDelegate.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var panelWindowManager: PanelWindowManager?
    var mouseEventMonitor: MouseEventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                // Don't show blocking dialog - just log it
                // User can grant permission later if needed
            }
        }
    }

    private func setupServices() {
        // Initialize panel window manager
        panelWindowManager = PanelWindowManager()

        // Initialize mouse event monitor
        mouseEventMonitor = MouseEventMonitor { [weak self] location in
            self?.handleMiddleClick(at: location)
        }

        mouseEventMonitor?.start()
    }

    private func handleMiddleClick(at location: CGPoint) {
        panelWindowManager?.togglePanel(at: location)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mouseEventMonitor?.stop()
    }
}
