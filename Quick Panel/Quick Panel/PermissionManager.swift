//
//  PermissionManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Cocoa
import ApplicationServices

class PermissionManager {
    static let shared = PermissionManager()

    private let promptCooldown: TimeInterval = 24 * 60 * 60
    private let lastPromptDateKey = "accessibilityPermissionLastPromptDate"

    private init() {}

    // MARK: - Accessibility

    func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission(force: Bool = false) {
        // Double check if we really don't have permission
        if checkAccessibilityPermission() {
            AppLogger.debug("辅助功能权限已授权，跳过请求。", category: .permission)
            return
        }

        if !force, !shouldShowPrompt() {
            AppLogger.info("辅助功能权限引导仍在冷却期内，跳过本次提示。", category: .permission)
            return
        }

        markPromptShown()
        AppLogger.notice("开始请求辅助功能权限。", category: .permission)

        let trusted: Bool
        if force {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }

        if !trusted {
            AppLogger.notice("系统未授予辅助功能权限，展示引导弹窗。", category: .permission)
            // Show custom alert with better instructions
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = """
                Quick Panel 需要辅助功能权限来监听鼠标中键事件。

                请按照以下步骤操作：
                1. 点击下方"打开系统设置"按钮
                2. 在左侧找到"隐私与安全性"
                3. 点击"辅助功能"
                4. 找到并勾选"Quick Panel"（如果看不到，请先尝试点击鼠标中键）
                5. 重启应用

                注意：如果应用刚安装，可能需要先运行一次才会出现在列表中。
                如果之前已经勾选但仍显示未授权，请关闭再打开开关，或移除旧的 Quick Panel 项后重新授权当前应用。
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")
                alert.addButton(withTitle: "退出应用")

                let response = alert.runModal()

                if response == .alertFirstButtonReturn {
                    self.openAccessibilitySettings()
                } else if response == .alertThirdButtonReturn {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func shouldShowPrompt() -> Bool {
        guard let lastPromptDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date else {
            return true
        }

        return Date().timeIntervalSince(lastPromptDate) >= promptCooldown
    }

    private func markPromptShown() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        UserDefaults.standard.synchronize()
    }

    func openAccessibilitySettings() {
        AppLogger.info("打开辅助功能系统设置。", category: .permission)

        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            AppLogger.error("辅助功能系统设置 URL 无效。", category: .permission)
            return
        }

        if !NSWorkspace.shared.open(url) {
            AppLogger.error("打开辅助功能系统设置失败。", category: .permission)
        }
    }
}
