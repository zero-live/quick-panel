//
//  IconStorage.swift
//  Quick Panel
//
//  Created by Codex on 2026/08/18.
//

import Foundation
import AppKit

class IconStorage {
    static let shared = IconStorage()

    private let directoryURL: URL
    private let logCategory: AppLogCategory = .data

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = appSupport
            .appendingPathComponent("Quick Panel", isDirectory: true)
            .appendingPathComponent("Icons", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            AppLogger.error("创建图标存储目录失败：\(error.localizedDescription)", category: logCategory)
        }
    }

    // MARK: - Read/Write

    func save(_ image: NSImage, for itemID: UUID) -> String? {
        guard let data = pngData(from: image) else {
            AppLogger.error("图标转换为 PNG 失败，itemID=\(itemID.uuidString)。", category: logCategory)
            return nil
        }

        let fileName = "\(itemID.uuidString).png"
        do {
            try data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            AppLogger.error("保存图标文件失败：\(error.localizedDescription)", category: logCategory)
            return nil
        }
    }

    func image(named fileName: String) -> NSImage? {
        guard isSafeFileName(fileName) else {
            AppLogger.notice("拒绝读取不安全的图标文件名：\(fileName)。", category: logCategory)
            return nil
        }
        return NSImage(contentsOf: directoryURL.appendingPathComponent(fileName))
    }

    func migrateLegacyIcon(for item: inout PanelItem) -> Bool {
        guard item.iconFileName == nil, let iconData = item.iconData, let image = NSImage(data: iconData) else {
            return false
        }
        guard let fileName = save(image, for: item.id) else { return false }

        item.iconFileName = fileName
        item.iconData = nil
        AppLogger.notice("已迁移项目图标到独立文件：\(item.name)。", category: logCategory)
        return true
    }

    func removeUnreferencedIcons(referencedBy fileNames: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in contents where !fileNames.contains(fileURL.lastPathComponent) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                AppLogger.error("清理孤立图标失败：\(error.localizedDescription)", category: logCategory)
            }
        }
    }

    // MARK: - Helpers

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func isSafeFileName(_ fileName: String) -> Bool {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        return fileName == safeName && safeName.lowercased().hasSuffix(".png")
    }
}
