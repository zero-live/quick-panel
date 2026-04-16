//
//  LogExportManager.swift
//  Quick Panel
//
//  Created by Codex on 2026/04/16.
//

import Cocoa
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
class LogExportManager: ObservableObject {
    static let shared = LogExportManager()

    @Published var isExporting = false
    @Published var lastExportMessage: String?
    @Published var lastExportSucceeded = false

    private init() {}

    func exportRecentLogs(hours: Int = 24) {
        guard !isExporting else { return }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = defaultFilename(hours: hours)
        savePanel.allowedContentTypes = [.plainText]
        savePanel.title = "导出调试日志"
        savePanel.message = "导出最近 \(hours) 小时的 Quick Panel 日志，便于排查问题。"

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else {
            return
        }

        isExporting = true
        lastExportMessage = nil
        lastExportSucceeded = false
        AppLogger.notice("开始导出最近 \(hours) 小时日志。", category: .app)

        Task.detached(priority: .userInitiated) {
            do {
                let contents = try self.buildLogContents(hours: hours)
                try contents.write(to: destinationURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    self.isExporting = false
                    self.lastExportSucceeded = true
                    self.lastExportMessage = "日志已导出到：\(destinationURL.path)"
                    AppLogger.notice("日志导出成功：\(destinationURL.path)。", category: .app)
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.lastExportSucceeded = false
                    self.lastExportMessage = "日志导出失败：\(error.localizedDescription)"
                    AppLogger.error("日志导出失败：\(error.localizedDescription)", category: .app)
                }
            }
        }
    }

    nonisolated private func buildLogContents(hours: Int) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--style", "compact",
            "--last", "\(hours)h",
            "--predicate", "subsystem == \"\(AppLogger.subsystem)\""
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "QuickPanel.LogExport",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: errorOutput?.isEmpty == false ? errorOutput! : "系统日志命令执行失败"
                ]
            )
        }

        let logOutput = String(data: outputData, encoding: .utf8) ?? ""
        let exportHeader = """
        Quick Panel 调试日志导出
        导出时间：\(ISO8601DateFormatter().string(from: Date()))
        最近时长：\(hours) 小时
        子系统：\(AppLogger.subsystem)

        ========================================

        """

        if logOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return exportHeader + "所选时间范围内没有可导出的日志。\n"
        }

        return exportHeader + logOutput
    }

    private func defaultFilename(hours: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "QuickPanel-logs-\(hours)h-\(formatter.string(from: Date())).log"
    }
}
