//
//  PageGroup.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation

struct PageGroup: Codable {
    var groups: [String: [Int: String]] = [:] // [layerName: [pageIndex: groupName]]

    func getGroupName(scopeKey: String, page: Int) -> String? {
        return groups[scopeKey]?[page]
    }

    func getGroupName(layer: PanelLayer, page: Int) -> String? {
        return getGroupName(scopeKey: layer.rawValue, page: page)
    }

    func maxPage(for scopeKey: String) -> Int {
        guard let layerGroups = groups[scopeKey], !layerGroups.isEmpty else {
            return 0
        }
        return layerGroups.keys.max() ?? 0
    }

    func maxPage(for layer: PanelLayer) -> Int {
        return maxPage(for: layer.rawValue)
    }

    mutating func setGroupName(scopeKey: String, page: Int, name: String?) {
        if groups[scopeKey] == nil {
            groups[scopeKey] = [:]
        }

        if let name = name, !name.isEmpty {
            groups[scopeKey]?[page] = name
        } else {
            groups[scopeKey]?[page] = nil
        }
    }

    mutating func setGroupName(layer: PanelLayer, page: Int, name: String?) {
        setGroupName(scopeKey: layer.rawValue, page: page, name: name)
    }

    mutating func removePage(scopeKey: String, page: Int) {
        guard var layerGroups = groups[scopeKey] else { return }

        layerGroups.removeValue(forKey: page)

        var shifted: [Int: String] = [:]
        for (key, value) in layerGroups {
            if key > page {
                shifted[key - 1] = value
            } else {
                shifted[key] = value
            }
        }

        groups[scopeKey] = shifted.isEmpty ? nil : shifted
    }

    mutating func removePage(layer: PanelLayer, page: Int) {
        removePage(scopeKey: layer.rawValue, page: page)
    }
}
