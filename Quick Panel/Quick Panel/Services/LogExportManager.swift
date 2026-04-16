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
                let contents = try AppLogger.exportableLogContents(hours: hours)
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

    private func defaultFilename(hours: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "QuickPanel-logs-\(hours)h-\(formatter.string(from: Date())).log"
    }
}
