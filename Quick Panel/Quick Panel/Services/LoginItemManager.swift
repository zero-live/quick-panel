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
    private let logCategory: AppLogCategory = .app

    private init() {}

    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                let status = SMAppService.mainApp.status
                if enabled, status != .enabled {
                    try SMAppService.mainApp.register()
                } else if !enabled, status != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }
                AppLogger.notice("开机启动状态更新成功，enabled=\(enabled)。", category: logCategory)
                return true
            } catch {
                AppLogger.error("设置开机启动失败：\(error.localizedDescription)", category: logCategory)
                return false
            }
        } else {
            AppLogger.notice("当前系统版本不支持开机启动设置。", category: logCategory)
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
