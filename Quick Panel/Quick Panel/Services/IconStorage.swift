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
    private let imageCache = NSCache<NSString, NSImage>()
    private let maximumPixelDimension: CGFloat = 256

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directoryURL = appSupport
            .appendingPathComponent("Quick Panel", isDirectory: true)
            .appendingPathComponent("Icons", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            imageCache.countLimit = 128
        } catch {
            AppLogger.error("创建图标存储目录失败：\(error.localizedDescription)", category: logCategory)
        }
    }

    // MARK: - Read/Write

    func save(_ image: NSImage, for itemID: UUID) -> String? {
        guard let normalizedImage = normalizedImage(from: image),
              let data = pngData(from: normalizedImage) else {
            AppLogger.error("图标转换为 PNG 失败，itemID=\(itemID.uuidString)。", category: logCategory)
            return nil
        }

        // Each edit receives a fresh file so config backups continue to refer
        // to the original image instead of a later overwrite.
        let fileName = "\(itemID.uuidString)-\(UUID().uuidString).png"
        do {
            try data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
            cache(normalizedImage, named: fileName)
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
        if let cachedImage = imageCache.object(forKey: fileName as NSString) {
            return cachedImage
        }

        guard let image = NSImage(contentsOf: directoryURL.appendingPathComponent(fileName)) else {
            return nil
        }
        cache(image, named: fileName)
        return image
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
                imageCache.removeObject(forKey: fileURL.lastPathComponent as NSString)
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

    private func normalizedImage(from image: NSImage) -> NSImage? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }

        let scale = min(1, maximumPixelDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = NSSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()

        let normalizedImage = NSImage(size: targetSize)
        normalizedImage.addRepresentation(bitmap)
        return normalizedImage
    }

    private func cache(_ image: NSImage, named fileName: String) {
        let cost = max(1, Int(image.size.width * image.size.height * 4))
        imageCache.setObject(image, forKey: fileName as NSString, cost: cost)
    }

    private func isSafeFileName(_ fileName: String) -> Bool {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        return fileName == safeName && safeName.lowercased().hasSuffix(".png")
    }
}
