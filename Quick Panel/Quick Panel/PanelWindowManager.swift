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
    private var dragMonitor: Any?
    private var clickOutsideMonitor: Any?
    private var localClickOutsideMonitor: Any?
    private var scrollWheelMonitor: Any?
    private let layoutManager = PanelLayoutManager.shared

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

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyScreenParameters()
        }
    }

    private func setupPanelWindow() {
        // Prevent creating multiple windows
        if windowCreated {
            AppLogger.debug("主面板窗口已创建，跳过重复初始化。", category: .panel)
            return
        }

        windowCreated = true
        AppLogger.info("开始创建主面板窗口。", category: .panel)

        let panelView = PanelView()
        let hostingController = NSHostingController(rootView: panelView)

        layoutManager.update(for: NSScreen.main)
        let panelSize = layoutManager.metrics.panelSize

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
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
        window.hasShadow = true
        window.alphaValue = 1

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 18 * layoutManager.metrics.scale
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
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }

        // Monitor for mouse events to enable dragging from drag handle area
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged]) { [weak window] event in
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
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
            self.clickOutsideMonitor = nil
        }

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hidePanelIfNeeded()
        }

        if let localClickOutsideMonitor {
            NSEvent.removeMonitor(localClickOutsideMonitor)
            self.localClickOutsideMonitor = nil
        }

        localClickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hidePanelIfNeeded()
            return event
        }
    }

    private func hidePanelIfNeeded() {
        guard isVisible, let panelWindow else { return }
        if !panelWindow.frame.contains(NSEvent.mouseLocation) {
            hidePanel()
        }
    }

    private func setupScrollWheelHandler(for window: NSWindow) {
        if let scrollWheelMonitor {
            NSEvent.removeMonitor(scrollWheelMonitor)
            self.scrollWheelMonitor = nil
        }

        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak window] event in
            guard let self = self, let window = window, event.window == window else { return event }

            let locationInWindow = event.locationInWindow
            let settings = SettingsManager.shared.settings
            let metrics = self.layoutManager.metrics
            let lowerLayerHeight = metrics.layerHeight(for: .lower, settings: settings)
            let dragHandleHeight = metrics.dragHandleHeight
            let dividerHeight = metrics.interLayerHeight
            let upperLayerMinY = lowerLayerHeight + dividerHeight
            let upperLayerMaxY = upperLayerMinY + metrics.layerHeight(for: .upper, settings: settings)
            let lowerLayerMaxY = lowerLayerHeight

            let targetLayer: PanelLayer?
            if locationInWindow.y >= upperLayerMinY && locationInWindow.y <= upperLayerMaxY {
                targetLayer = .upper
            } else if locationInWindow.y >= 0 && locationInWindow.y <= lowerLayerMaxY {
                targetLayer = .lower
            } else if locationInWindow.y > upperLayerMaxY && locationInWindow.y <= upperLayerMaxY + dragHandleHeight {
                targetLayer = .upper
            } else {
                targetLayer = nil
            }

            guard let targetLayer else {
                return nil
            }

            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastScrollTime > 0.3 else {
                return nil
            }

            if event.scrollingDeltaY > 3 {
                self.lastScrollTime = now
                NotificationCenter.default.post(
                    name: .scrollPreviousPage,
                    object: nil,
                    userInfo: ["layer": targetLayer.rawValue]
                )
                return nil
            } else if event.scrollingDeltaY < -3 {
                self.lastScrollTime = now
                NotificationCenter.default.post(
                    name: .scrollNextPage,
                    object: nil,
                    userInfo: ["layer": targetLayer.rawValue]
                )
                return nil
            }

            return nil
        }
    }

    func togglePanel(at location: CGPoint) {
        if isVisible {
            AppLogger.debug("切换主面板：执行隐藏。", category: .panel)
            hidePanel()
        } else {
            AppLogger.debug("切换主面板：执行显示。", category: .panel)
            ContextDetector.shared.refreshCurrentApp()
            showPanel(at: location)
        }
    }

    func showPanel(at location: CGPoint) {
        // If already visible, don't show again
        if isVisible {
            AppLogger.debug("主面板已显示，忽略重复 show 请求。", category: .panel)
            return
        }

        // Create window if it doesn't exist yet (lazy initialization)
        if panelWindow == nil {
            setupPanelWindow()
        }

        guard let window = panelWindow else {
            AppLogger.error("主面板窗口为空，无法显示。", category: .panel)
            return
        }

        let targetScreen = screenContaining(point: location)
        layoutManager.update(for: targetScreen)


        // Notify that panel is about to show (before it becomes frontmost)
        NotificationCenter.default.post(name: .panelWillShow, object: nil)

        // Calculate window position
        let windowSize = layoutManager.metrics.panelSize
        var origin = CGPoint(
            x: location.x - windowSize.width / 2,
            y: location.y - windowSize.height / 2
        )

        // Adjust position to avoid screen edges
        if let screen = targetScreen {
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

        window.setFrame(NSRect(origin: origin, size: windowSize), display: true)
        window.orderFrontRegardless()
        // Don't call makeKey() for nonactivatingPanel - it causes warnings and isn't needed
        // window.makeKey()

        isVisible = true
        AppLogger.info("主面板已显示，位置=(\(Int(origin.x)), \(Int(origin.y)))。", category: .panel)
    }

    func hidePanel() {
        panelWindow?.orderOut(nil)
        isVisible = false
        AppLogger.debug("主面板已隐藏。", category: .panel)
    }

    private func applySettings() {
        guard let window = panelWindow else {
            AppLogger.debug("主面板窗口未创建，跳过设置应用。", category: .panel)
            return
        }

        let currentFrame = window.frame
        let center = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let screen = screenContaining(point: center)
        layoutManager.update(for: screen)
        let newSize = layoutManager.metrics.panelSize

        if abs(currentFrame.width - newSize.width) > 0.5 || abs(currentFrame.height - newSize.height) > 0.5 {
            var newOrigin = CGPoint(
                x: center.x - newSize.width / 2,
                y: center.y - newSize.height / 2
            )

            if let screen {
                let visibleFrame = screen.visibleFrame
                newOrigin.x = min(max(newOrigin.x, visibleFrame.minX), max(visibleFrame.minX, visibleFrame.maxX - newSize.width))
                newOrigin.y = min(max(newOrigin.y, visibleFrame.minY), max(visibleFrame.minY, visibleFrame.maxY - newSize.height))
            }

            window.setFrame(
                NSRect(origin: newOrigin, size: newSize),
                display: true,
                animate: isVisible
            )
        }

        // Keep content fully opaque. Panel opacity is applied only to the glass
        // background so icons and labels never fade together with the material.
        window.alphaValue = 1
        window.contentView?.layer?.cornerRadius = 18 * layoutManager.metrics.scale
        let settings = SettingsManager.shared.settings
        AppLogger.info("主面板设置已应用：\(Int(newSize.width))x\(Int(newSize.height))，缩放=\(Int(layoutManager.metrics.scale * 100))%，玻璃透明度=\(Int(settings.panelOpacity * 100))%。", category: .panel)
    }

    private func applyScreenParameters() {
        guard let window = panelWindow else { return }

        let frame = window.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        layoutManager.update(for: screenContaining(point: center))

        guard isVisible else { return }
        applySettings()
    }

    private func screenContaining(point: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            screen.frame.contains(point)
        } ?? NSScreen.main
    }

    deinit {
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        if let localClickOutsideMonitor {
            NSEvent.removeMonitor(localClickOutsideMonitor)
        }
        if let scrollWheelMonitor {
            NSEvent.removeMonitor(scrollWheelMonitor)
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let scrollPreviousPage = Notification.Name("scrollPreviousPage")
    static let scrollNextPage = Notification.Name("scrollNextPage")
    static let panelWillShow = Notification.Name("panelWillShow")
}
