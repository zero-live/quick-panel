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

    private init() {}

    // MARK: - Accessibility

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        // Double check if we really don't have permission
        if checkAccessibilityPermission() {
            return
        }


        // First, trigger the system prompt by calling with prompt option
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
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
                """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")
                alert.addButton(withTitle: "退出应用")

                let response = alert.runModal()

                if response == .alertFirstButtonReturn {
                    // Open System Settings - try different approaches for different macOS versions
                    self.openAccessibilitySettings()
                } else if response == .alertThirdButtonReturn {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    func openAccessibilitySettings() {
        // Try multiple methods to open accessibility settings

        // Method 1: Direct URL scheme (works on macOS 13+)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        // Method 2: Fallback - open Security & Privacy pane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let script = """
            tell application "System Settings"
                activate
                delay 0.5
                reveal pane id "com.apple.preference.security"
            end tell
            """

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                }
            }
        }
    }
}
