//
//  PanelWindowManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class PanelWindowManager {
    private var panelWindow: NSWindow?
    private var isVisible = false

    init() {
        setupPanelWindow()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .hidePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func setupPanelWindow() {
        let panelView = PanelView()
        let hostingController = NSHostingController(rootView: panelView)

        // Create custom window with updated size (added 24pt for drag handle)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 364),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true  // Allow dragging by background
        window.hasShadow = true

        // Setup click-outside-to-hide behavior
        setupClickOutsideHandler(for: window)

        self.panelWindow = window
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

    func togglePanel(at location: CGPoint) {
        print("🎯 Toggle panel called at: \(location), current visible: \(isVisible)")
        if isVisible {
            hidePanel()
        } else {
            showPanel(at: location)
        }
    }

    func showPanel(at location: CGPoint) {
        guard let window = panelWindow else {
            print("❌ Panel window is nil!")
            return
        }

        print("👀 Showing panel...")

        // Calculate window position
        let windowSize = window.frame.size
        var origin = location

        // Adjust position to avoid screen edges
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame

            // Offset from mouse cursor
            origin.x += 10
            origin.y -= windowSize.height + 10

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
        print("🙈 Hiding panel")
        panelWindow?.orderOut(nil)
        isVisible = false
    }
}
