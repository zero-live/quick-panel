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

    nonisolated private static let logQueue = DispatchQueue(label: "com.benxin.quick-panel.logger", qos: .utility)
    nonisolated private static let maxLogFileSize = 2 * 1024 * 1024
    nonisolated private static let maxLogFileSizeAfterTrim = 1 * 1024 * 1024
    nonisolated private static let retentionDays = 7

    private static func logger(for category: AppLogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    nonisolated private static var fileManager: FileManager {
        FileManager.default
    }

    nonisolated private static var logsDirectoryURL: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return applicationSupport
            .appendingPathComponent("Quick Panel", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    nonisolated private static func logFileURL(for date: Date) -> URL {
        logsDirectoryURL.appendingPathComponent("app-\(fileDateString(for: date)).log")
    }

    nonisolated private static func fileDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    nonisolated private static func logTimestampString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }

    nonisolated private static func parseLogTimestamp(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
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

    static func clearLogs() throws {
        try logQueue.sync {
            try ensureLogDirectoryExists()
            let fileURLs = try listLogFiles()
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
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
        导出时间：\(logTimestampString(for: Date()))
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
        let line = "\(logTimestampString(for: timestamp))\t\(level)\t\(category.rawValue)\t\(escapedMessage)\n"

        logQueue.async {
            do {
                try ensureLogDirectoryExists()
                try cleanupExpiredLogFiles(referenceDate: timestamp)
                let fileURL = logFileURL(for: timestamp)
                try append(line: line, to: fileURL)
                try trimIfNeeded(fileURL: fileURL)
            } catch {
                logger(for: .app).error("写入本地日志失败：\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    nonisolated private static func readEntries(withinLastHours hours: Int) throws -> [AppLogEntry] {
        try ensureLogDirectoryExists()

        let cutoffDate = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? .distantPast
        let logFiles = try listLogFiles()

        let contentsList = try logQueue.sync {
            try logFiles.map { fileURL in
                try String(contentsOf: fileURL, encoding: .utf8)
            }
        }

        return contentsList
            .joined(separator: "\n")
            .split(whereSeparator: \.isNewline)
            .compactMap { parseEntry(from: String($0)) }
            .filter { $0.timestamp >= cutoffDate }
            .sorted { $0.timestamp < $1.timestamp }
    }

    nonisolated private static func parseEntry(from line: String) -> AppLogEntry? {
        let components = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
        guard components.count == 4 else { return nil }
        guard let timestamp = parseLogTimestamp(String(components[0])) else { return nil }

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

    nonisolated private static func listLogFiles() throws -> [URL] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: logsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        return fileURLs
            .filter { $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    nonisolated private static func append(line: String, to fileURL: URL) throws {
        let data = Data(line.utf8)

        if !fileManager.fileExists(atPath: fileURL.path) {
            try data.write(to: fileURL, options: .atomic)
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    nonisolated private static func trimIfNeeded(fileURL: URL) throws {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int ?? 0

        guard fileSize > maxLogFileSize else { return }

        let data = try Data(contentsOf: fileURL)
        let startOffset = max(data.count - maxLogFileSizeAfterTrim, 0)
        var trimmedData = data.subdata(in: startOffset..<data.count)

        if startOffset > 0, let newlineIndex = trimmedData.firstIndex(of: 0x0A), newlineIndex < trimmedData.endIndex {
            let contentStart = trimmedData.index(after: newlineIndex)
            trimmedData = trimmedData.subdata(in: contentStart..<trimmedData.endIndex)
        }

        try trimmedData.write(to: fileURL, options: .atomic)
    }

    nonisolated private static func cleanupExpiredLogFiles(referenceDate: Date) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -(retentionDays - 1), to: referenceDate) ?? referenceDate
        let cutoffPrefix = fileDateString(for: cutoffDate)
        let files = try listLogFiles()

        for fileURL in files {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            guard filename.hasPrefix("app-") else { continue }
            let filePrefix = String(filename.dropFirst(4))
            if filePrefix < cutoffPrefix {
                try fileManager.removeItem(at: fileURL)
            }
        }
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
