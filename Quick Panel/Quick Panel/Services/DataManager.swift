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
    @Published var pageCounts: [String: Int] = [:]

    private let configDirectory: URL
    private let configFile: URL
    private let groupsFile: URL
    private let pageCountsFile: URL
    private let unboundLowerScope = "__unbound__"

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configDirectory = appSupport.appendingPathComponent("Quick Panel")
        configFile = configDirectory.appendingPathComponent("config.json")
        groupsFile = configDirectory.appendingPathComponent("groups.json")
        pageCountsFile = configDirectory.appendingPathComponent("pagecounts.json")

        try? FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)

        loadItems()
        loadPageGroups()
        loadPageCounts()

    }

    // MARK: - Load/Save

    func loadItems() {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: configFile)
            items = try JSONDecoder().decode([PanelItem].self, from: data)
            normalizeOrders(save: false)
        } catch {
        }
    }

    func saveItems() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: configFile)
        } catch {
        }
    }

    // MARK: - CRUD Operations

    func addItem(_ item: PanelItem) {
        items.append(item)
        normalizeOrders(save: false)
        saveItems()
    }

    func updateItem(_ item: PanelItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            normalizeOrders(save: false)
            saveItems()
        }
    }

    func deleteItem(_ item: PanelItem) {
        items.removeAll { $0.id == item.id }
        normalizeOrders(save: false)
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

    func swapItems(layer: PanelLayer, appBundleIdentifier: String? = nil, fromIndex: Int, toIndex: Int) {
        var layerItems = getItems(for: layer, appBundleIdentifier: appBundleIdentifier)

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

        normalizeOrders(save: false)
        saveItems()
    }

    // MARK: - Utility

    func getItems(for layer: PanelLayer, appBundleIdentifier: String? = nil) -> [PanelItem] {
        let filteredItems = items.filter { item in
            guard item.layer == layer else { return false }

            if layer == .lower, let appBundleIdentifier {
                return item.appBundleIdentifier == appBundleIdentifier
            }

            return true
        }

        return filteredItems.sorted { $0.order < $1.order }
    }

    func getItemsForCurrentApp(bundleIdentifier: String?) -> [PanelItem] {
        guard let bundleId = bundleIdentifier else {
            return []
        }
        return getItems(for: .lower, appBundleIdentifier: bundleId)
    }

    func clearAllItems() {
        items.removeAll()
        saveItems()
    }

    func legacyUnboundLowerItems() -> [PanelItem] {
        items.filter { item in
            guard item.layer == .lower else { return false }
            guard let bundleIdentifier = item.appBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return true
            }
            return bundleIdentifier.isEmpty
        }
        .sorted { $0.order < $1.order }
    }

    func migrateLegacyUnboundLowerItemsToUpper() {
        let legacyItems = legacyUnboundLowerItems()
        guard !legacyItems.isEmpty else { return }

        var nextUpperOrder = (getItems(for: .upper).map(\.order).max() ?? -1) + 1

        for legacyItem in legacyItems {
            guard let index = items.firstIndex(where: { $0.id == legacyItem.id }) else { continue }
            items[index].layer = .upper
            items[index].appBundleIdentifier = nil
            items[index].order = nextUpperOrder
            nextUpperOrder += 1
        }

        normalizeOrders(save: false)
        saveItems()
    }

    // MARK: - Page Groups

    func loadPageGroups() {
        guard FileManager.default.fileExists(atPath: groupsFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: groupsFile)
            pageGroups = try JSONDecoder().decode(PageGroup.self, from: data)
        } catch {
        }
    }

    func savePageGroups() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(pageGroups)
            try data.write(to: groupsFile)
        } catch {
        }
    }

    func getPageGroupName(layer: PanelLayer, page: Int, appBundleIdentifier: String? = nil) -> String? {
        return pageGroups.getGroupName(scopeKey: pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier), page: page)
    }

    func setPageGroup(layer: PanelLayer, page: Int, name: String?, appBundleIdentifier: String? = nil) {
        pageGroups.setGroupName(
            scopeKey: pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier),
            page: page,
            name: name
        )
        savePageGroups()
    }

    // MARK: - Page Counts

    func loadPageCounts() {
        guard FileManager.default.fileExists(atPath: pageCountsFile.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: pageCountsFile)
            pageCounts = try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
        }
    }

    func savePageCounts() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(pageCounts)
            try data.write(to: pageCountsFile)
        } catch {
        }
    }

    func getPageCount(for layer: PanelLayer, appBundleIdentifier: String? = nil) -> Int {
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
        if let count = pageCounts[scopeKey] {
            return count
        }

        if layer == .lower, let legacyCount = pageCounts[layer.rawValue] {
            return legacyCount
        }

        return 1
    }

    func addPage(layer: PanelLayer, appBundleIdentifier: String? = nil) -> Int {
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
        let current = getPageCount(for: layer, appBundleIdentifier: appBundleIdentifier)
        pageCounts[scopeKey] = current + 1
        savePageCounts()
        return current
    }

    func deletePage(layer: PanelLayer, page: Int, itemsPerPage: Int, appBundleIdentifier: String? = nil) {
        let pageStartOrder = page * itemsPerPage
        let pageEndOrder = pageStartOrder + itemsPerPage
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)

        items.removeAll { item in
            item.layer == layer &&
            matchesOrderScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier) &&
            item.order >= pageStartOrder &&
            item.order < pageEndOrder
        }

        for index in items.indices {
            if items[index].layer == layer &&
                matchesOrderScope(item: items[index], layer: layer, appBundleIdentifier: appBundleIdentifier) &&
                items[index].order >= pageEndOrder {
                items[index].order -= itemsPerPage
            }
        }

        pageGroups.removePage(scopeKey: scopeKey, page: page)

        let current = getPageCount(for: layer, appBundleIdentifier: appBundleIdentifier)
        pageCounts[scopeKey] = max(1, current - 1)

        normalizeOrders(save: false)
        saveItems()
        savePageGroups()
        savePageCounts()
    }

    // MARK: - Helpers

    private func pageScopeKey(layer: PanelLayer, appBundleIdentifier: String?) -> String {
        switch layer {
        case .upper:
            return layer.rawValue
        case .lower:
            let scopeIdentifier = appBundleIdentifier ?? unboundLowerScope
            return "\(layer.rawValue)::\(scopeIdentifier)"
        }
    }

    private func orderScopeKey(for item: PanelItem) -> String {
        return pageScopeKey(layer: item.layer, appBundleIdentifier: item.appBundleIdentifier)
    }

    private func matchesOrderScope(item: PanelItem, layer: PanelLayer, appBundleIdentifier: String?) -> Bool {
        return orderScopeKey(for: item) == pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
    }

    private func normalizeOrders(save: Bool) {
        var normalizedItems = items
        var didChange = false

        let groupedIndices = Dictionary(grouping: normalizedItems.indices, by: { orderScopeKey(for: normalizedItems[$0]) })

        for indices in groupedIndices.values {
            let sortedIndices = indices.sorted { lhs, rhs in
                let lhsItem = normalizedItems[lhs]
                let rhsItem = normalizedItems[rhs]

                if lhsItem.order == rhsItem.order {
                    return lhsItem.id.uuidString < rhsItem.id.uuidString
                }

                return lhsItem.order < rhsItem.order
            }

            for (normalizedOrder, index) in sortedIndices.enumerated() {
                if normalizedItems[index].order != normalizedOrder {
                    normalizedItems[index].order = normalizedOrder
                    didChange = true
                }
            }
        }

        if didChange {
            items = normalizedItems
            if save {
                saveItems()
            }
        }
    }
}
