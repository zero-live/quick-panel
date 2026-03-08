//
//  PageGroup.swift
//  Quick Panel
//
//  Created by Claude on 2025/12/28.
//

import Foundation

struct PageGroup: Codable {
    var groups: [String: [Int: String]] = [:] // [layerName: [pageIndex: groupName]]
    
    func getGroupName(layer: PanelLayer, page: Int) -> String? {
        return groups[layer.rawValue]?[page]
    }
    
    func maxPage(for layer: PanelLayer) -> Int {
        guard let layerGroups = groups[layer.rawValue], !layerGroups.isEmpty else {
            return 0
        }
        return layerGroups.keys.max() ?? 0
    }
    
    mutating func setGroupName(layer: PanelLayer, page: Int, name: String?) {
        if groups[layer.rawValue] == nil {
            groups[layer.rawValue] = [:]
        }
        
        if let name = name, !name.isEmpty {
            groups[layer.rawValue]?[page] = name
        } else {
            groups[layer.rawValue]?[page] = nil
        }
    }
}
