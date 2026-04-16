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
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                return false
            }
        } else {
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
