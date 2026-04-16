//
//  AddItemWindowManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class AddItemWindowManager {
    static let shared = AddItemWindowManager()

    private var addWindow: NSWindow?
    private var editWindow: NSWindow?

    private init() {}

    func showAddItemWindow(layer: PanelLayer = .upper, appBundleId: String? = nil, appName: String? = nil, page: Int = 0) {
        addWindow?.close()

        let resolvedBinding = resolvedBindingContext(
            layer: layer,
            appBundleId: appBundleId,
            appName: appName
        )

        let addView = AddItemView(
            presetLayer: layer,
            presetAppBundleId: resolvedBinding.bundleIdentifier,
            presetAppName: resolvedBinding.appName,
            targetPage: page
        )
        let hostingController = NSHostingController(rootView: addView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "添加项目"
        window.center()
        window.level = .modalPanel  // Higher level to stay on top
        window.isReleasedWhenClosed = false

        // Setup window close notification
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.addWindow = nil
        }

        addWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAddItemWindow() {
        addWindow?.close()
        addWindow = nil
    }

    func showEditItemWindow(item: PanelItem) {
        // Close existing window if any
        editWindow?.close()

        let editView = EditItemView(item: item)
        let hostingController = NSHostingController(rootView: editView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "编辑项目"
        window.center()
        window.level = .modalPanel  // Higher level to stay on top
        window.isReleasedWhenClosed = false

        // Setup window close notification
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.editWindow = nil
        }

        editWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeEditItemWindow() {
        editWindow?.close()
        editWindow = nil
    }

    private func resolvedBindingContext(layer: PanelLayer, appBundleId: String?, appName: String?) -> (bundleIdentifier: String?, appName: String?) {
        guard layer == .lower else {
            return (appBundleId, appName)
        }

        if let appBundleId, let appName {
            return (appBundleId, appName)
        }

        let currentApp = ContextDetector.shared.frontmostAppInfo
        return (appBundleId ?? currentApp?.bundleIdentifier, appName ?? currentApp?.appName)
    }
}
