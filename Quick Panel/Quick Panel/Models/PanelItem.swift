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
    var iconData: Data?  // Custom icon (PNG data)
    var browserPath: String?  // Optional: specific browser for websites
    var layer: PanelLayer  // Upper or lower layer
    var appBundleIdentifier: String?  // For lower layer: bind to specific app (e.g., "com.microsoft.edgemac")
    var order: Int

    init(id: UUID = UUID(), name: String, type: ItemType, path: String, iconData: Data? = nil, browserPath: String? = nil, layer: PanelLayer = .upper, appBundleIdentifier: String? = nil, order: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.path = path
        self.iconData = iconData
        self.browserPath = browserPath
        self.layer = layer
        self.appBundleIdentifier = appBundleIdentifier
        self.order = order
    }

    // Helper to get icon synchronously
    func getIcon() -> NSImage? {
        // If custom icon data exists, use it
        if let iconData = iconData, let image = NSImage(data: iconData) {
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
        // If custom icon data exists, use it
        if let iconData = iconData, let image = NSImage(data: iconData) {
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
}
