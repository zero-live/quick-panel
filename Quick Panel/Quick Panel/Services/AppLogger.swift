//
//  AppLogger.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import Foundation
import AppKit
import OSLog

enum AppLogCategory: String {
    case app
    case panel
    case permission
    case data
    case network
    case addItem
}

struct AppLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let category: String
    let message: String
}

enum AppLogger {
    nonisolated static let subsystem = "com.benxin.Quick-Panel"

    nonisolated(unsafe) private static let fileManager = FileManager.default
    nonisolated private static let logQueue = DispatchQueue(label: "com.benxin.quick-panel.logger", qos: .utility)
    nonisolated(unsafe) private static let iso8601Formatter = ISO8601DateFormatter()
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    nonisolated private static let maxLogFileSize = 2 * 1024 * 1024
    nonisolated private static let maxLogFileSizeAfterTrim = 1 * 1024 * 1024

    private static func logger(for category: AppLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    nonisolated private static var logsDirectoryURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return applicationSupport
            .appendingPathComponent("Quick Panel", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    nonisolated private static var logFileURL: URL {
        logsDirectoryURL.appendingPathComponent("app.log")
    }

    nonisolated private static func displayDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    static func openLogsDirectory() {
        do {
            try ensureLogDirectoryExists()
            NSWorkspace.shared.open(logsDirectoryURL)
        } catch {
            logger(for: .app).error("打开日志目录失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    static func debug(_ message: String, category: AppLogCategory) {
        logger(for: category).debug("\(message, privacy: .public)")
        write(level: "DEBUG", message: message, category: category)
    }

    static func info(_ message: String, category: AppLogCategory) {
        logger(for: category).info("\(message, privacy: .public)")
        write(level: "INFO", message: message, category: category)
    }

    static func notice(_ message: String, category: AppLogCategory) {
        logger(for: category).notice("\(message, privacy: .public)")
        write(level: "NOTICE", message: message, category: category)
    }

    static func error(_ message: String, category: AppLogCategory) {
        logger(for: category).error("\(message, privacy: .public)")
        write(level: "ERROR", message: message, category: category)
    }

    static func fault(_ message: String, category: AppLogCategory) {
        logger(for: category).fault("\(message, privacy: .public)")
        write(level: "FAULT", message: message, category: category)
    }

    nonisolated static func exportableLogContents(hours: Int) throws -> String {
        let entries = try readEntries(withinLastHours: hours)
        let header = """
        Quick Panel 调试日志导出
        导出时间：\(iso8601Formatter.string(from: Date()))
        最近时长：\(hours) 小时
        子系统：\(subsystem)

        ========================================

        """

        if entries.isEmpty {
            return header + "所选时间范围内没有可导出的日志。\n"
        }

        let body = entries
            .map { "[\(displayDateString(for: $0.timestamp))] [\($0.level)] [\($0.category)] \($0.message)" }
            .joined(separator: "\n")

        return header + body + "\n"
    }

    private static func write(level: String, message: String, category: AppLogCategory) {
        let timestamp = Date()
        let escapedMessage = escape(message)
        let line = "\(iso8601Formatter.string(from: timestamp))\t\(level)\t\(category.rawValue)\t\(escapedMessage)\n"

        logQueue.async {
            do {
                try ensureLogDirectoryExists()
                try append(line: line)
                try trimIfNeeded()
            } catch {
                logger(for: .app).error("写入本地日志失败：\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated private static func readEntries(withinLastHours hours: Int) throws -> [AppLogEntry] {
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            return []
        }

        let contents = try logQueue.sync {
            try String(contentsOf: logFileURL, encoding: .utf8)
        }

        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? .distantPast

        return contents
            .split(whereSeparator: \.isNewline)
            .compactMap { parseEntry(from: String($0)) }
            .filter { $0.timestamp >= cutoffDate }
    }

    nonisolated private static func parseEntry(from line: String) -> AppLogEntry? {
        let components = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
        guard components.count == 4 else { return nil }
        guard let timestamp = iso8601Formatter.date(from: String(components[0])) else { return nil }

        return AppLogEntry(
            timestamp: timestamp,
            level: String(components[1]),
            category: String(components[2]),
            message: unescape(String(components[3]))
        )
    }

    nonisolated private static func ensureLogDirectoryExists() throws {
        if !fileManager.fileExists(atPath: logsDirectoryURL.path) {
            try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func append(line: String) throws {
        let data = Data(line.utf8)

        if !fileManager.fileExists(atPath: logFileURL.path) {
            try data.write(to: logFileURL, options: .atomic)
            return
        }

        let handle = try FileHandle(forWritingTo: logFileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    nonisolated private static func trimIfNeeded() throws {
        let attributes = try fileManager.attributesOfItem(atPath: logFileURL.path)
        let fileSize = attributes[.size] as? Int ?? 0

        guard fileSize > maxLogFileSize else { return }

        let data = try Data(contentsOf: logFileURL)
        let startOffset = max(data.count - maxLogFileSizeAfterTrim, 0)
        var trimmedData = data.subdata(in: startOffset..<data.count)

        if startOffset > 0, let newlineIndex = trimmedData.firstIndex(of: 0x0A), newlineIndex < trimmedData.endIndex {
            let contentStart = trimmedData.index(after: newlineIndex)
            trimmedData = trimmedData.subdata(in: contentStart..<trimmedData.endIndex)
        }

        try trimmedData.write(to: logFileURL, options: .atomic)
    }

    nonisolated private static func escape(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    nonisolated private static func unescape(_ message: String) -> String {
        var result = ""
        var iterator = message.makeIterator()
        var isEscaping = false

        while let character = iterator.next() {
            if isEscaping {
                switch character {
                case "t":
                    result.append("\t")
                case "n":
                    result.append("\n")
                case "\\":
                    result.append("\\")
                default:
                    result.append("\\")
                    result.append(character)
                }
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                result.append(character)
            }
        }

        if isEscaping {
            result.append("\\")
        }

        return result
    }
}
