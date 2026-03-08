//
//  DataManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var items: [PanelItem] = []
    @Published var pageGroups = PageGroup()

    private let configDirectory: URL
    private let configFile: URL
    private let groupsFile: URL

    private init() {
        // Setup config directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Quick Panel")
        configFile = configDirectory.appendingPathComponent("config.json")
        groupsFile = configDirectory.appendingPathComponent("groups.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)

        // Load data
        loadItems()
        loadPageGroups()

        // Don't create default items - let users add their own
        print("📦 Loaded \(items.count) items. Users can add items using the '+' button.")
    }

    // MARK: - Load/Save

    func loadItems() {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            print("📂 No config file found, will create defaults")
            return
        }

        do {
            let data = try Data(contentsOf: configFile)
            items = try JSONDecoder().decode([PanelItem].self, from: data)
            print("✅ Loaded \(items.count) items from config")
        } catch {
            print("❌ Failed to load config: \(error.localizedDescription)")
        }
    }

    func saveItems() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: configFile)
            print("✅ Saved \(items.count) items to config")
        } catch {
            print("❌ Failed to save config: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD Operations

    func addItem(_ item: PanelItem) {
        items.append(item)
        saveItems()
    }

    func updateItem(_ item: PanelItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }

    func deleteItem(_ item: PanelItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func moveItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < items.count,
              destinationIndex >= 0, destinationIndex <= items.count else {
            return
        }

        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        saveItems()
    }

    func swapItems(layer: PanelLayer, fromIndex: Int, toIndex: Int) {
        var layerItems = getItems(for: layer)

        guard fromIndex >= 0, fromIndex < layerItems.count,
              toIndex >= 0, toIndex < layerItems.count,
              fromIndex != toIndex else {
            return
        }

        let fromOrder = layerItems[fromIndex].order
        let toOrder = layerItems[toIndex].order
        layerItems[fromIndex].order = toOrder
        layerItems[toIndex].order = fromOrder

        for layerItem in layerItems {
            if let mainIndex = items.firstIndex(where: { $0.id == layerItem.id }) {
                items[mainIndex] = layerItem
            }
        }

        saveItems()
        print("✅ Swapped items at \(fromIndex) and \(toIndex) in \(layer) layer")
    }

    // MARK: - Utility

    func getItems(for layer: PanelLayer) -> [PanelItem] {
        return items.filter { $0.layer == layer }.sorted { $0.order < $1.order }
    }

    func getItemsForCurrentApp(bundleIdentifier: String?) -> [PanelItem] {
        guard let bundleId = bundleIdentifier else {
            return []
        }
        return items.filter {
            $0.layer == .lower && $0.appBundleIdentifier == bundleId
        }.sorted { $0.order < $1.order }
    }

    func clearAllItems() {
        items.removeAll()
        saveItems()
        print("🗑️ Cleared all items")
    }

    // MARK: - Page Groups

    func loadPageGroups() {
        guard FileManager.default.fileExists(atPath: groupsFile.path) else {
            print("📂 No groups file found")
            return
        }

        do {
            let data = try Data(contentsOf: groupsFile)
            pageGroups = try JSONDecoder().decode(PageGroup.self, from: data)
            print("✅ Loaded page groups")
        } catch {
            print("❌ Failed to load page groups: \(error.localizedDescription)")
        }
    }

    func savePageGroups() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(pageGroups)
            try data.write(to: groupsFile)
            print("✅ Saved page groups")
        } catch {
            print("❌ Failed to save page groups: \(error.localizedDescription)")
        }
    }

    func setPageGroup(layer: PanelLayer, page: Int, name: String?) {
        pageGroups.setGroupName(layer: layer, page: page, name: name)
        savePageGroups()
    }

    func deletePage(layer: PanelLayer, page: Int, itemsPerPage: Int) {
        let pageStartOrder = page * itemsPerPage
        let pageEndOrder = pageStartOrder + itemsPerPage

        items.removeAll { item in
            item.layer == layer && item.order >= pageStartOrder && item.order < pageEndOrder
        }

        for index in items.indices {
            if items[index].layer == layer && items[index].order >= pageEndOrder {
                items[index].order -= itemsPerPage
            }
        }

        pageGroups.removePage(layer: layer, page: page)

        saveItems()
        savePageGroups()
        print("🗑️ Deleted page \(page) from \(layer) layer")
    }
}
