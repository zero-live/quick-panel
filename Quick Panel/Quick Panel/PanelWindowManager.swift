//
//  PanelWindowManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class PanelWindowManager {
    static let shared = PanelWindowManager()

    private var panelWindow: NSWindow?
    private var isVisible = false
    private var windowCreated = false
    private var lastScrollTime: TimeInterval = 0

    private init() {
        setupNotifications()
        setupPanelWindow()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .hidePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePanel()
        }

        // Listen for settings changes
        NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applySettings()
        }
    }

    private func setupPanelWindow() {
        // Prevent creating multiple windows
        if windowCreated {
            print("⚠️ Panel window already created, skipping")
            return
        }

        windowCreated = true
        print("🏗️ Creating panel window...")

        let panelView = PanelView()
        let hostingController = NSHostingController(rootView: panelView)

        // Get dynamic window size from settings
        let settings = SettingsManager.shared.settings
        let width = settings.panelWidth
        let height = settings.layerHeight(for: .upper) + settings.layerHeight(for: .lower) + 44  // Two layers + drag handle(24) + divider(20)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false  // Disable automatic dragging
        window.hasShadow = false
        window.alphaValue = settings.panelOpacity

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 18
            contentView.layer?.masksToBounds = true
        }

        // Enable dragging only from specific view (drag handle)
        setupDragHandler(for: window)

        // Setup click-outside-to-hide behavior
        setupClickOutsideHandler(for: window)

        // Setup scroll wheel handler
        setupScrollWheelHandler(for: window)

        self.panelWindow = window
    }

    private func setupDragHandler(for window: NSWindow) {
        // Monitor for mouse events to enable dragging from drag handle area
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { [weak window] event in
            guard let window = window, event.window == window else { return event }

            let locationInWindow = event.locationInWindow
            // Only allow dragging from top 30pt (drag handle area)
            if locationInWindow.y > window.frame.height - 30 {
                if event.type == .leftMouseDown {
                    // Start tracking for drag
                    window.performDrag(with: event)
                }
            }

            return event
        }
    }

    private func setupClickOutsideHandler(for window: NSWindow) {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panelWindow = self.panelWindow else { return }

            if self.isVisible {
                // Check if click is outside the panel window
                let clickLocation = NSEvent.mouseLocation
                let windowFrame = panelWindow.frame

                if !windowFrame.contains(clickLocation) {
                    self.hidePanel()
                }
            }
        }
    }

    private func setupScrollWheelHandler(for window: NSWindow) {
        NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak window] event in
            guard let self = self, let window = window, event.window == window else { return event }

            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastScrollTime > 0.3 else { return event }

            let locationInWindow = event.locationInWindow
            
            let settings = SettingsManager.shared.settings
            let lowerLayerHeight = settings.layerHeight(for: .lower)
            
            let isUpperLayer = locationInWindow.y > lowerLayerHeight

            if event.scrollingDeltaY > 3 {
                self.lastScrollTime = now
                NotificationCenter.default.post(
                    name: .scrollPreviousPage,
                    object: nil,
                    userInfo: ["layer": isUpperLayer ? "upper" : "lower"]
                )
            } else if event.scrollingDeltaY < -3 {
                self.lastScrollTime = now
                NotificationCenter.default.post(
                    name: .scrollNextPage,
                    object: nil,
                    userInfo: ["layer": isUpperLayer ? "upper" : "lower"]
                )
            }

            return event
        }
    }

    func togglePanel(at location: CGPoint) {
        print("🎯 Toggle panel called at: \(location), current visible: \(isVisible), window exists: \(panelWindow != nil)")
        if isVisible {
            hidePanel()
        } else {
            showPanel(at: location)
        }
    }

    func showPanel(at location: CGPoint) {
        // If already visible, don't show again
        if isVisible {
            print("⚠️ Panel already visible, ignoring show request")
            return
        }

        // Create window if it doesn't exist yet (lazy initialization)
        if panelWindow == nil {
            setupPanelWindow()
        }

        guard let window = panelWindow else {
            print("❌ Panel window is nil after setup!")
            return
        }

        print("👀 Showing panel...")

        // Notify that panel is about to show (before it becomes frontmost)
        NotificationCenter.default.post(name: .panelWillShow, object: nil)

        // Calculate window position
        let windowSize = window.frame.size
        var origin = CGPoint(
            x: location.x - windowSize.width / 2,
            y: location.y - windowSize.height / 2
        )

        // Adjust position to avoid screen edges
        if let screen = screenContaining(point: location) {
            let screenFrame = screen.visibleFrame

            // Keep within screen bounds
            if origin.x + windowSize.width > screenFrame.maxX {
                origin.x = screenFrame.maxX - windowSize.width
            }
            if origin.x < screenFrame.minX {
                origin.x = screenFrame.minX
            }
            if origin.y < screenFrame.minY {
                origin.y = screenFrame.minY
            }
            if origin.y + windowSize.height > screenFrame.maxY {
                origin.y = screenFrame.maxY - windowSize.height
            }
        }

        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        // Don't call makeKey() for nonactivatingPanel - it causes warnings and isn't needed
        // window.makeKey()

        isVisible = true
        print("✅ Panel shown at: \(origin)")
    }

    func hidePanel() {
        print("🙈 Hiding panel, window count: \(NSApplication.shared.windows.count)")
        panelWindow?.orderOut(nil)
        isVisible = false

        // Debug: print all windows
        for (index, window) in NSApplication.shared.windows.enumerated() {
            print("  Window \(index): \(window.title) - visible: \(window.isVisible)")
        }
    }

    private func applySettings() {
        guard let window = panelWindow else {
            print("⚠️ Panel window not created yet, settings will be applied on creation")
            return
        }

        let settings = SettingsManager.shared.settings

        // Recalculate window size
        let width = settings.panelWidth
        let height = settings.layerHeight(for: .upper) + settings.layerHeight(for: .lower) + 44

        // Hide panel before resizing if it's visible
        let wasVisible = isVisible
        if wasVisible {
            hidePanel()
        }

        // Update window size
        window.setContentSize(NSSize(width: width, height: height))

        // Update window opacity
        window.alphaValue = settings.panelOpacity

        print("⚙️ Settings applied: \(Int(width))×\(Int(height))pt, opacity: \(Int(settings.panelOpacity * 100))%")
    }

    private func screenContaining(point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            screen.frame.contains(point)
        } ?? NSScreen.main
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let scrollPreviousPage = Notification.Name("scrollPreviousPage")
    static let scrollNextPage = Notification.Name("scrollNextPage")
    static let panelWillShow = Notification.Name("panelWillShow")
}
