//
//  DataManager.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation
import Combine

struct GridPosition: Hashable, Codable {
    var page: Int
    var slot: Int
}

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
    private let logCategory: AppLogCategory = .data

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
        AppLogger.info("数据管理器初始化完成，当前项目数=\(items.count)。", category: logCategory)
    }

    // MARK: - Load/Save

    func loadItems() {
        if let loadedItems: [PanelItem] = loadValue(from: configFile, label: "项目配置") {
            items = loadedItems
            normalizePositions(save: false)
        }
    }

    func saveItems() {
        saveValue(items, to: configFile, label: "项目配置")
    }

    private func loadValue<Value: Decodable>(from fileURL: URL, label: String) -> Value? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            AppLogger.debug("\(label)文件不存在，跳过加载。", category: logCategory)
            return nil
        }

        let backupURL = fileURL.appendingPathExtension("backup")
        var primaryError: Error?

        for candidateURL in [fileURL, backupURL] where fileManager.fileExists(atPath: candidateURL.path) {
            do {
                let data = try Data(contentsOf: candidateURL)
                let value = try JSONDecoder().decode(Value.self, from: data)

                if candidateURL == backupURL {
                    archiveCorruptFile(at: fileURL)
                    try data.write(to: fileURL, options: .atomic)
                    AppLogger.notice("\(label)已从备份恢复。", category: logCategory)
                }
                return value
            } catch {
                if candidateURL == fileURL {
                    primaryError = error
                }
                AppLogger.error("读取\(label)失败（\(candidateURL.lastPathComponent)）：\(error.localizedDescription)", category: logCategory)
            }
        }

        archiveCorruptFile(at: fileURL)
        if let primaryError {
            AppLogger.error("\(label)无法恢复，原文件已保留为副本：\(primaryError.localizedDescription)", category: logCategory)
        }
        return nil
    }

    private func saveValue<Value: Encodable>(_ value: Value, to fileURL: URL, label: String) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try writeAtomically(data, to: fileURL)
        } catch {
            AppLogger.error("保存\(label)失败：\(error.localizedDescription)", category: logCategory)
        }
    }

    private func writeAtomically(_ data: Data, to fileURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            let currentData = try Data(contentsOf: fileURL)
            try currentData.write(to: fileURL.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private func archiveCorruptFile(at fileURL: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let archiveURL = fileURL.deletingLastPathComponent().appendingPathComponent(
            "\(fileURL.lastPathComponent).corrupt-\(timestamp)"
        )
        do {
            try fileManager.copyItem(at: fileURL, to: archiveURL)
            AppLogger.notice("已保留无法读取的配置副本：\(archiveURL.lastPathComponent)。", category: logCategory)
        } catch {
            AppLogger.error("保留异常配置副本失败：\(error.localizedDescription)", category: logCategory)
        }
    }

    // MARK: - CRUD Operations

    func addItem(_ item: PanelItem) {
        items.append(item)
        normalizePositions(save: false)
        saveItems()
        AppLogger.info("已添加项目：\(item.name)，layer=\(item.layer.rawValue)。", category: logCategory)
    }

    func updateItem(_ item: PanelItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        items[index] = item
        normalizePositions(save: false)
        saveItems()
        AppLogger.info("已更新项目：\(item.name)，layer=\(item.layer.rawValue)。", category: logCategory)
    }

    func deleteItem(_ item: PanelItem) {
        items.removeAll { $0.id == item.id }
        normalizePositions(save: false)
        saveItems()
        AppLogger.notice("已删除项目：\(item.name)。", category: logCategory)
    }

    func moveItem(id: UUID, layer: PanelLayer, appBundleIdentifier: String? = nil, toPage: Int, slotIndex: Int, itemsPerPage: Int) {
        normalizePositions(save: false)

        guard itemsPerPage > 0,
              let movingIndex = items.firstIndex(where: { item in
                  item.id == id &&
                  item.layer == layer &&
                  matchesScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier)
              }) else {
            return
        }

        let targetPosition = GridPosition(
            page: max(0, toPage),
            slot: min(max(0, slotIndex), itemsPerPage - 1)
        )
        let sourceItem = items[movingIndex]
        let sourcePosition = GridPosition(page: max(0, sourceItem.page), slot: min(max(0, sourceItem.slot), itemsPerPage - 1))
        guard sourcePosition != targetPosition else { return }

        var updatedItems = items
        var occupiedIndices: [GridPosition: Int] = [:]
        for index in updatedItems.indices {
            guard index != movingIndex,
                  updatedItems[index].layer == layer,
                  matchesScope(item: updatedItems[index], layer: layer, appBundleIdentifier: appBundleIdentifier) else {
                continue
            }

            let position = GridPosition(page: max(0, updatedItems[index].page), slot: min(max(0, updatedItems[index].slot), itemsPerPage - 1))
            occupiedIndices[position] = index
        }

        if occupiedIndices[targetPosition] != nil {
            shiftItemsForwardForInsertion(
                to: targetPosition,
                occupiedIndices: occupiedIndices,
                itemsPerPage: itemsPerPage,
                in: &updatedItems
            )
        }

        updatedItems[movingIndex].page = targetPosition.page
        updatedItems[movingIndex].slot = targetPosition.slot
        items = updatedItems
        saveItems()
        AppLogger.debug("已移动项目到页面槽位：layer=\(layer.rawValue)，page=\(targetPosition.page)，slot=\(targetPosition.slot)。", category: logCategory)
    }

    func replaceItems(for layer: PanelLayer, appBundleIdentifier: String? = nil, with replacementItems: [PanelItem]) {
        var updatedItems = items.filter { item in
            !(item.layer == layer && matchesScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier))
        }
        updatedItems.append(contentsOf: replacementItems)
        items = updatedItems
        normalizePositions(save: false)
        saveItems()
        AppLogger.debug("已批量更新项目布局：layer=\(layer.rawValue)，count=\(replacementItems.count)。", category: logCategory)
    }

    func replacePageItems(for layer: PanelLayer, appBundleIdentifier: String? = nil, page: Int, with replacementItems: [PanelItem]) {
        var updatedItems = items.filter { item in
            !(item.layer == layer &&
              matchesScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier) &&
              item.page == page)
        }
        updatedItems.append(contentsOf: replacementItems)
        items = updatedItems
        normalizePositions(save: false)
        saveItems()
        AppLogger.debug("已更新页面项目布局：layer=\(layer.rawValue)，page=\(page)，count=\(replacementItems.count)。", category: logCategory)
    }

    // MARK: - Utility

    func getItems(for layer: PanelLayer, appBundleIdentifier: String? = nil) -> [PanelItem] {
        items
            .filter { item in
                guard item.layer == layer else { return false }

                if layer == .lower, let appBundleIdentifier {
                    return item.appBundleIdentifier == appBundleIdentifier
                }

                return true
            }
            .sorted(by: sortByPosition)
    }

    func getItemsForCurrentApp(bundleIdentifier: String?) -> [PanelItem] {
        guard let bundleId = bundleIdentifier else {
            return []
        }
        return getItems(for: .lower, appBundleIdentifier: bundleId)
    }

    func itemAt(layer: PanelLayer, appBundleIdentifier: String? = nil, page: Int, slot: Int) -> PanelItem? {
        items.first { item in
            item.layer == layer &&
            matchesScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier) &&
            item.page == page &&
            item.slot == slot
        }
    }

    func nextAvailablePosition(for layer: PanelLayer, appBundleIdentifier: String? = nil, preferredPage: Int, itemsPerPage: Int) -> GridPosition {
        guard itemsPerPage > 0 else {
            return GridPosition(page: max(0, preferredPage), slot: 0)
        }

        let targetPage = max(0, preferredPage)
        let scopedItems = getItems(for: layer, appBundleIdentifier: appBundleIdentifier)
        let occupiedLinearIndexes = Set(scopedItems.map {
            max(0, $0.page) * itemsPerPage + min(max(0, $0.slot), itemsPerPage - 1)
        })

        var linearIndex = targetPage * itemsPerPage
        while occupiedLinearIndexes.contains(linearIndex) {
            linearIndex += 1
        }
        return position(fromLinearIndex: linearIndex, itemsPerPage: itemsPerPage)
    }

    func clearAllItems() {
        items.removeAll()
        saveItems()
        AppLogger.notice("已清空所有项目。", category: logCategory)
    }

    func legacyUnboundLowerItems() -> [PanelItem] {
        items
            .filter { item in
                guard item.layer == .lower else { return false }
                guard let bundleIdentifier = item.appBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return true
                }
                return bundleIdentifier.isEmpty
            }
            .sorted(by: sortByPosition)
    }

    func migrateLegacyUnboundLowerItemsToUpper() {
        let legacyItems = legacyUnboundLowerItems()
        guard !legacyItems.isEmpty else { return }

        let settings = SettingsManager.shared.settings
        var nextPosition = nextAvailablePosition(
            for: .upper,
            preferredPage: 0,
            itemsPerPage: settings.upperItemsPerPage
        )

        for legacyItem in legacyItems {
            guard let index = items.firstIndex(where: { $0.id == legacyItem.id }) else { continue }
            items[index].layer = .upper
            items[index].appBundleIdentifier = nil
            items[index].page = nextPosition.page
            items[index].slot = nextPosition.slot

            let nextLinearIndex = nextPosition.page * settings.upperItemsPerPage + nextPosition.slot + 1
            nextPosition = GridPosition(
                page: nextLinearIndex / settings.upperItemsPerPage,
                slot: nextLinearIndex % settings.upperItemsPerPage
            )
        }

        normalizePositions(save: false)
        saveItems()
        AppLogger.notice("已迁移未绑定下层项目到上层，数量=\(legacyItems.count)。", category: logCategory)
    }

    // MARK: - Page Groups

    func loadPageGroups() {
        if let loadedGroups: PageGroup = loadValue(from: groupsFile, label: "分页分组") {
            pageGroups = loadedGroups
        }
    }

    func savePageGroups() {
        saveValue(pageGroups, to: groupsFile, label: "分页分组")
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
        if let loadedPageCounts: [String: Int] = loadValue(from: pageCountsFile, label: "分页数量") {
            pageCounts = loadedPageCounts
        }
    }

    func savePageCounts() {
        saveValue(pageCounts, to: pageCountsFile, label: "分页数量")
    }

    func getPageCount(for layer: PanelLayer, appBundleIdentifier: String? = nil) -> Int {
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
        let manualCount = pageCounts[scopeKey] ?? 1
        let maxItemPage = getItems(for: layer, appBundleIdentifier: appBundleIdentifier).map(\.page).max() ?? 0
        return max(1, manualCount, maxItemPage + 1)
    }

    func addPage(layer: PanelLayer, appBundleIdentifier: String? = nil) -> Int {
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
        let current = getPageCount(for: layer, appBundleIdentifier: appBundleIdentifier)
        pageCounts[scopeKey] = current + 1
        savePageCounts()
        return current
    }

    func deletePage(layer: PanelLayer, page: Int, appBundleIdentifier: String? = nil) {
        let scopeKey = pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)

        items.removeAll { item in
            item.layer == layer &&
            matchesScope(item: item, layer: layer, appBundleIdentifier: appBundleIdentifier) &&
            item.page == page
        }

        for index in items.indices where items[index].layer == layer &&
            matchesScope(item: items[index], layer: layer, appBundleIdentifier: appBundleIdentifier) &&
            items[index].page > page {
            items[index].page -= 1
        }

        pageGroups.removePage(scopeKey: scopeKey, page: page)

        let current = getPageCount(for: layer, appBundleIdentifier: appBundleIdentifier)
        pageCounts[scopeKey] = max(1, current - 1)

        normalizePositions(save: false)
        saveItems()
        savePageGroups()
        savePageCounts()
        AppLogger.notice("已删除页面：layer=\(layer.rawValue)，page=\(page)。", category: logCategory)
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

    private func matchesScope(item: PanelItem, layer: PanelLayer, appBundleIdentifier: String?) -> Bool {
        pageScopeKey(layer: item.layer, appBundleIdentifier: item.appBundleIdentifier) ==
            pageScopeKey(layer: layer, appBundleIdentifier: appBundleIdentifier)
    }

    private func sortByPosition(_ lhs: PanelItem, _ rhs: PanelItem) -> Bool {
        if lhs.page != rhs.page {
            return lhs.page < rhs.page
        }

        if lhs.slot != rhs.slot {
            return lhs.slot < rhs.slot
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func normalizePositions(save: Bool) {
        let settings = SettingsManager.shared.settings
        var didChange = false
        let groupedIndices = Dictionary(grouping: items.indices, by: { pageScopeKey(layer: items[$0].layer, appBundleIdentifier: items[$0].appBundleIdentifier) })

        for indices in groupedIndices.values {
            let sortedIndices = indices.sorted { lhs, rhs in
                sortByPosition(items[lhs], items[rhs])
            }
            let layer = sortedIndices.first.map { items[$0].layer } ?? .upper
            let itemsPerPage = max(1, settings.itemsPerPage(for: layer))
            var usedPositions = Set<GridPosition>()

            for index in sortedIndices {
                var position = GridPosition(
                    page: max(0, items[index].page),
                    slot: min(max(0, items[index].slot), itemsPerPage - 1)
                )

                while usedPositions.contains(position) {
                    let nextLinearIndex = position.page * itemsPerPage + position.slot + 1
                    position = GridPosition(page: nextLinearIndex / itemsPerPage, slot: nextLinearIndex % itemsPerPage)
                }

                usedPositions.insert(position)

                if items[index].page != position.page || items[index].slot != position.slot {
                    items[index].page = position.page
                    items[index].slot = position.slot
                    didChange = true
                }
            }
        }

        if didChange && save {
            saveItems()
        }
    }

    private func shiftItemsForwardForInsertion(to targetPosition: GridPosition, occupiedIndices: [GridPosition: Int], itemsPerPage: Int, in updatedItems: inout [PanelItem]) {
        let targetLinearIndex = linearIndex(for: targetPosition, itemsPerPage: itemsPerPage)
        var occupiedChain: [(linearIndex: Int, itemIndex: Int)] = []
        var scanLinearIndex = targetLinearIndex

        while let itemIndex = occupiedIndices[position(fromLinearIndex: scanLinearIndex, itemsPerPage: itemsPerPage)] {
            occupiedChain.append((linearIndex: scanLinearIndex, itemIndex: itemIndex))
            scanLinearIndex += 1
        }

        for entry in occupiedChain.reversed() {
            let destinationPosition = position(fromLinearIndex: entry.linearIndex + 1, itemsPerPage: itemsPerPage)
            updatedItems[entry.itemIndex].page = destinationPosition.page
            updatedItems[entry.itemIndex].slot = destinationPosition.slot
        }
    }

    private func linearIndex(for position: GridPosition, itemsPerPage: Int) -> Int {
        max(0, position.page) * itemsPerPage + min(max(0, position.slot), itemsPerPage - 1)
    }

    private func position(fromLinearIndex linearIndex: Int, itemsPerPage: Int) -> GridPosition {
        GridPosition(page: max(0, linearIndex) / itemsPerPage, slot: max(0, linearIndex) % itemsPerPage)
    }
}
