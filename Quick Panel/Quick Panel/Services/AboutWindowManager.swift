//
//  AboutWindowManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class AboutWindowManager {
    static let shared = AboutWindowManager()

    private var aboutWindow: NSWindow?

    private init() {}

    func showAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "关于 Quick Panel"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.aboutWindow = nil
        }

        aboutWindow = window

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

        print("ℹ️ About window opened at center")
    }
}
