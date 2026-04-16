//
//  AppLogger.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import Foundation
import OSLog

enum AppLogCategory: String {
    case app
    case panel
    case permission
    case data
    case network
    case addItem
}

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.benxin.Quick-Panel"

    private static func logger(for category: AppLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func debug(_ message: String, category: AppLogCategory) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: AppLogCategory) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func notice(_ message: String, category: AppLogCategory) {
        logger(for: category).notice("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: AppLogCategory) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    static func fault(_ message: String, category: AppLogCategory) {
        logger(for: category).fault("\(message, privacy: .public)")
    }
}
