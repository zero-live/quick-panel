//
//  LoginItemManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import ServiceManagement

class LoginItemManager {
    static let shared = LoginItemManager()

    private init() {}

    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ Launch at login enabled")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("🚫 Launch at login disabled")
                }
                return true
            } catch {
                print("❌ Failed to set launch at login: \(error.localizedDescription)")
                return false
            }
        } else {
            print("⚠️ Launch at login requires macOS 13.0+")
            return false
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }
}
