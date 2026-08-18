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
    private var addWindowCloseObserver: NSObjectProtocol?
    private var editWindowCloseObserver: NSObjectProtocol?

    private init() {}

    func showAddItemWindow(layer: PanelLayer = .upper, appBundleId: String? = nil, appName: String? = nil, page: Int = 0, slot: Int? = nil) {
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
            targetPage: page,
            targetSlot: slot
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

        removeAddWindowCloseObserver()
        addWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.addWindow = nil
            self?.removeAddWindowCloseObserver()
        }

        addWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeAddItemWindow() {
        addWindow?.close()
        addWindow = nil
        removeAddWindowCloseObserver()
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

        removeEditWindowCloseObserver()
        editWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.editWindow = nil
            self?.removeEditWindowCloseObserver()
        }

        editWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeEditItemWindow() {
        editWindow?.close()
        editWindow = nil
        removeEditWindowCloseObserver()
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

    private func removeAddWindowCloseObserver() {
        if let observer = addWindowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            addWindowCloseObserver = nil
        }
    }

    private func removeEditWindowCloseObserver() {
        if let observer = editWindowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            editWindowCloseObserver = nil
        }
    }
}
