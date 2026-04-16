//
//  ChangelogWindowManager.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import Cocoa
import SwiftUI

class ChangelogWindowManager {
    static let shared = ChangelogWindowManager()

    private var changelogWindow: NSWindow?

    private init() {}

    func showChangelog() {
        if let window = changelogWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let changelogView = ChangelogView()
        let hostingController = NSHostingController(rootView: changelogView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "更新日志"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 700, height: 480)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.changelogWindow = nil
        }

        changelogWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
