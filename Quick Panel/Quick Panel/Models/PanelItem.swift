//
//  PanelItem.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import AppKit

enum PanelLayer: String, Codable {
    case upper = "upper"  // Top layer
    case lower = "lower"  // Bottom layer
}

struct PanelItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ItemType
    var path: String  // App path or website URL
    var iconData: Data?  // Legacy inline icon data, migrated to iconFileName after loading
    var iconFileName: String?  // Custom icon stored in Application Support/Quick Panel/Icons
    var browserPath: String?  // Optional: specific browser for websites
    var layer: PanelLayer  // Upper or lower layer
    var appBundleIdentifier: String?  // For lower layer: bind to specific app (e.g., "com.microsoft.edgemac")
    var page: Int
    var slot: Int

    init(id: UUID = UUID(), name: String, type: ItemType, path: String, iconData: Data? = nil, iconFileName: String? = nil, browserPath: String? = nil, layer: PanelLayer = .upper, appBundleIdentifier: String? = nil, page: Int, slot: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.iconData = iconData
        self.iconFileName = iconFileName
        self.browserPath = browserPath
        self.layer = layer
        self.appBundleIdentifier = appBundleIdentifier
        self.page = page
        self.slot = slot
    }

    // Older configurations did not persist page and slot. Keep those files
    // readable so an app update never turns an existing panel into an empty one.
    private enum CodingKeys: String, CodingKey {
        case id, name, type, path, iconData, iconFileName, browserPath, layer, appBundleIdentifier, page, slot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ItemType.self, forKey: .type)
        path = try container.decode(String.self, forKey: .path)
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        iconFileName = try container.decodeIfPresent(String.self, forKey: .iconFileName)
        browserPath = try container.decodeIfPresent(String.self, forKey: .browserPath)
        layer = try container.decodeIfPresent(PanelLayer.self, forKey: .layer) ?? .upper
        appBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .appBundleIdentifier)
        page = max(0, try container.decodeIfPresent(Int.self, forKey: .page) ?? 0)
        slot = max(0, try container.decodeIfPresent(Int.self, forKey: .slot) ?? 0)
    }

    // Helper to get icon synchronously
    func getIcon() -> NSImage? {
        if let image = customIcon() {
            return image
        }

        // Otherwise get default icon based on type
        switch type {
        case .application:
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil)

        case .website:
            // Return a default web icon for immediate display
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }
    }

    // Helper to load icon asynchronously (for websites)
    func loadIconAsync(completion: @escaping (NSImage?) -> Void) {
        if let image = customIcon() {
            completion(image)
            return
        }

        switch type {
        case .application:
            completion(getIcon())

        case .website:
            IconFetcher.shared.fetchFavicon(for: path) { image in
                completion(image ?? self.getIcon())
            }
        }
    }

    func customIcon() -> NSImage? {
        if let iconFileName, let image = IconStorage.shared.image(named: iconFileName) {
            return image
        }

        if let iconData, let image = NSImage(data: iconData) {
            return image
        }

        return nil
    }
}
