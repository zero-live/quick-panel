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
    private let logCategory: AppLogCategory = .app

    private init() {}

    func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            AppLogger.debug("设置窗口已存在，直接置前。", category: logCategory)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Quick Panel 设置"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 600, height: 500)
        window.setFrameAutosaveName("Settings")
        window.isReleasedWhenClosed = false

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindow = nil
            AppLogger.debug("设置窗口已关闭。", category: self?.logCategory ?? .app)
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
        AppLogger.info("设置窗口已打开。", category: logCategory)
    }

    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
        AppLogger.debug("主动关闭设置窗口。", category: logCategory)
    }
}
