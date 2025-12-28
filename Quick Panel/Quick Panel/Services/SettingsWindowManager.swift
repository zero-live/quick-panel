//
//  SettingsWindowManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var settingsWindow: NSWindow?

    private init() {}

    func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("✅ Settings window brought to front")
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Quick Panel 设置"
        window.contentViewController = hostingController
        window.setFrameAutosaveName("Settings")
        window.isReleasedWhenClosed = false

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            print("🔒 Settings window closed")
        }

        settingsWindow = window

        // Center the window on screen - do this after all setup to ensure proper positioning
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("✅ Settings window opened at center")
    }

    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}
