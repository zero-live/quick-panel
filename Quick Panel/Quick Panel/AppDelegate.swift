//
//  AppDelegate.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var mouseEventMonitor: MouseEventMonitor?
    var hotkeyManager: HotkeyManager?

    private var hasLaunched = false
    private var hasPromptedForAccessibility = false
    private let logCategory: AppLogCategory = .app

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple launches
        if hasLaunched {
            AppLogger.debug("应用已完成启动，忽略重复启动回调。", category: logCategory)
            return
        }
        hasLaunched = true

        // Check for existing instances
        if !checkSingleInstance() {
            AppLogger.fault("检测到多个实例，应用将退出。", category: logCategory)
            exit(0)
        }

        // Hide the default window
        NSApplication.shared.windows.first?.close()

        // Keep app running in background
        NSApp.setActivationPolicy(.accessory)

        AppLogger.info("应用启动完成，开始初始化服务。", category: logCategory)

        // Always setup services first (will use backup method if no permission)
        setupServices()

        // Check accessibility permission after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let hasPermission = PermissionManager.shared.checkAccessibilityPermission()

            if !hasPermission, self.mouseEventMonitor?.isUsingBackupMethod() == true {
                AppLogger.notice("当前使用备用事件监听方式，准备提示辅助功能权限。", category: self.logCategory)
                self.promptForAccessibilityIfNeeded()
            }
        }
    }

    private func setupServices() {
        // Load settings
        _ = SettingsManager.shared

        // Setup status bar
        StatusBarManager.shared.setupStatusBar()

        // Apply launch at login setting
        let settings = SettingsManager.shared.settings
        if settings.launchAtLogin {
            _ = LoginItemManager.shared.setLaunchAtLogin(true)
        }

        // Initialize panel window manager
        _ = PanelWindowManager.shared

        // Initialize mouse event monitor
        mouseEventMonitor = MouseEventMonitor { [weak self] location in
            self?.handleMiddleClick(at: location)
        }

        mouseEventMonitor?.start()

        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            UpdateManager.shared.performAutomaticCheckIfNeeded()
        }
    }

    private func handleMiddleClick(at location: CGPoint) {
        AppLogger.debug("收到中键触发，准备切换主面板。", category: logCategory)
        PanelWindowManager.shared.togglePanel(at: location)
    }

    private func promptForAccessibilityIfNeeded() {
        guard !hasPromptedForAccessibility else { return }
        hasPromptedForAccessibility = true
        AppLogger.notice("触发辅助功能权限引导。", category: logCategory)
        PermissionManager.shared.requestAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mouseEventMonitor?.stop()
        hotkeyManager?.stop()
    }

    private func checkSingleInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            AppLogger.notice("无法获取 Bundle ID，跳过单实例校验。", category: logCategory)
            return true
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let instances = runningApps.filter { $0.bundleIdentifier == bundleID }


        // Should only find ourselves
        if instances.count > 1 {
            return false
        }

        return true
    }
}
