//
//  StatusBarManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class StatusBarManager {
    static let shared = StatusBarManager()

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    private init() {}

    func setupStatusBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let statusItem = statusItem else {
            print("❌ Failed to create status item")
            return
        }

        // Set icon
        if let button = statusItem.button {
            // Try to use app icon, fallback to system icon
            if let appIcon = NSApplication.shared.applicationIconImage {
                let iconImage = appIcon.copy() as! NSImage
                iconImage.size = NSSize(width: 18, height: 18)
                button.image = iconImage
            } else {
                button.image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Quick Panel")
            }
            button.imagePosition = .imageOnly
        }

        // Create menu
        setupMenu()

        print("✅ Status bar setup complete")
    }

    private func setupMenu() {
        statusMenu = NSMenu()

        guard let menu = statusMenu else { return }

        // Open Settings
        let settingsItem = NSMenuItem(
            title: "打开设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Toggle Panel
        let togglePanelItem = NSMenuItem(
            title: "显示/隐藏面板",
            action: #selector(togglePanel),
            keyEquivalent: "p"
        )
        togglePanelItem.target = self
        menu.addItem(togglePanelItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(
            title: "关于 Quick Panel",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "退出 Quick Panel",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func openSettings() {
        print("📝 Opening settings...")
        SettingsWindowManager.shared.showSettings()
    }

    @objc private func togglePanel() {
        print("🎯 Toggling panel from status bar")
        // Get mouse location and toggle panel
        let location = NSEvent.mouseLocation
        PanelWindowManager.shared.togglePanel(at: location)
    }

    @objc private func showAbout() {
        print("ℹ️ Showing about...")
        AboutWindowManager.shared.showAbout()
    }

    @objc private func quit() {
        print("👋 Quitting Quick Panel")
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - PanelWindowManager Access

extension StatusBarManager {
    private var panelWindowManager: PanelWindowManager {
        return PanelWindowManager.shared
    }
}
